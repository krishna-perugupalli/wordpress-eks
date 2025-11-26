# Karpenter Integration with Standalone ALB

This document explains how Karpenter node autoscaling integrates with the standalone ALB architecture using TargetGroupBinding.

## Overview

Karpenter is a Kubernetes cluster autoscaler that provisions and manages EC2 instances based on pod scheduling requirements. In the standalone ALB architecture, Karpenter works seamlessly with TargetGroupBinding to ensure that WordPress pods on new nodes are automatically registered with the ALB target group.

## Architecture Integration

### Traditional Challenges
In traditional ALB setups with instance target types, adding new nodes requires:
1. Registering new EC2 instances with the target group
2. Managing target group membership as nodes come and go
3. Handling the delay between node creation and target registration

### TargetGroupBinding Solution
With TargetGroupBinding and IP target types:
1. **Node Creation**: Karpenter provisions new EC2 instances
2. **Pod Scheduling**: Kubernetes schedules WordPress pods on new nodes
3. **Automatic Registration**: TargetGroupBinding registers pod IPs (not node IPs) with the target group
4. **Immediate Availability**: Pods are available for traffic as soon as they pass health checks

## Configuration

### Karpenter NodePool Configuration

```yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: wordpress-nodepool
spec:
  # Template for nodes
  template:
    metadata:
      labels:
        workload-type: "wordpress"
    spec:
      # Instance requirements
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: node.kubernetes.io/instance-type
          operator: In
          values: ["t3.medium", "t3.large", "t3.xlarge"]
      
      # Node class reference
      nodeClassRef:
        apiVersion: karpenter.k8s.aws/v1beta1
        kind: EC2NodeClass
        name: wordpress-nodeclass
      
      # Taints for dedicated WordPress nodes (optional)
      taints:
        - key: workload-type
          value: wordpress
          effect: NoSchedule

  # Scaling limits
  limits:
    cpu: 1000
    memory: 1000Gi
  
  # Disruption settings
  disruption:
    consolidationPolicy: WhenUnderutilized
    consolidateAfter: 30s
    expireAfter: 30m
```

### EC2NodeClass Configuration

```yaml
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: wordpress-nodeclass
spec:
  # AMI selection
  amiFamily: AL2
  
  # Subnet selection (private subnets)
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "wp-cluster"
        kubernetes.io/role/internal-elb: "1"
  
  # Security group selection
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "wp-cluster"
  
  # Instance profile
  role: "KarpenterNodeInstanceProfile"
  
  # User data for node initialization
  userData: |
    #!/bin/bash
    /etc/eks/bootstrap.sh wp-cluster
    
    # Optional: Configure container runtime settings
    echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
    sysctl -p
```

### WordPress Deployment with Node Affinity

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: wordpress
spec:
  replicas: 3
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      # Tolerate Karpenter taints
      tolerations:
        - key: workload-type
          operator: Equal
          value: wordpress
          effect: NoSchedule
      
      # Prefer Karpenter nodes
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - key: workload-type
                    operator: In
                    values: ["wordpress"]
      
      containers:
        - name: wordpress
          image: bitnami/wordpress:latest
          ports:
            - containerPort: 8080
              name: http
          # Resource requests trigger Karpenter scaling
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: 1000m
              memory: 1Gi
```

## Scaling Scenarios

### Scale-Up Events

1. **Trigger**: WordPress HPA increases replica count due to high CPU/memory usage
2. **Pod Pending**: New pods are created but remain in Pending state (no available nodes)
3. **Karpenter Detection**: Karpenter detects unschedulable pods
4. **Node Provisioning**: Karpenter provisions new EC2 instances matching pod requirements
5. **Pod Scheduling**: Kubernetes schedules pending pods on new nodes
6. **Target Registration**: TargetGroupBinding automatically registers new pod IPs
7. **Health Checks**: ALB health checks validate new targets
8. **Traffic Distribution**: ALB distributes traffic to all healthy targets

**Timeline**: Typically 2-3 minutes from scale trigger to serving traffic

### Scale-Down Events

1. **Trigger**: WordPress HPA decreases replica count due to low resource usage
2. **Pod Termination**: Kubernetes terminates excess pods
3. **Target Deregistration**: TargetGroupBinding deregisters pod IPs from target group
4. **Connection Draining**: ALB drains existing connections (30-second delay)
5. **Node Consolidation**: Karpenter evaluates node utilization
6. **Node Termination**: Karpenter terminates underutilized nodes after consolidation delay

**Timeline**: Pod termination is immediate; node termination after 30-second consolidation delay

### Node Replacement Events

1. **Trigger**: Spot instance interruption or node failure
2. **Pod Eviction**: Kubernetes evicts pods from the failing node
3. **Target Deregistration**: TargetGroupBinding deregisters pod IPs
4. **New Node Provisioning**: Karpenter provisions replacement node
5. **Pod Rescheduling**: Kubernetes reschedules pods on new node
6. **Target Registration**: TargetGroupBinding registers new pod IPs
7. **Service Restoration**: Traffic resumes to rescheduled pods

**Timeline**: 2-3 minutes for complete replacement cycle

## Monitoring and Observability

### Key Metrics to Monitor

**Karpenter Metrics**:
- `karpenter_nodes_total`: Total number of nodes managed by Karpenter
- `karpenter_pods_startup_duration_seconds`: Time to schedule pods on new nodes
- `karpenter_nodes_termination_duration_seconds`: Time to terminate nodes

**ALB Target Group Metrics**:
- `TargetResponseTime`: Response time from WordPress pods
- `HealthyHostCount`: Number of healthy pod targets
- `UnHealthyHostCount`: Number of unhealthy pod targets

**WordPress Metrics**:
- Pod CPU/memory utilization
- Pod readiness probe success rate
- Application response times

### CloudWatch Alarms

```yaml
# Unhealthy targets alarm
UnhealthyTargetsAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: WordPress-UnhealthyTargets
    MetricName: UnHealthyHostCount
    Namespace: AWS/ApplicationELB
    Statistic: Average
    Period: 60
    EvaluationPeriods: 2
    Threshold: 1
    ComparisonOperator: GreaterThanOrEqualToThreshold

# High response time alarm
HighResponseTimeAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: WordPress-HighResponseTime
    MetricName: TargetResponseTime
    Namespace: AWS/ApplicationELB
    Statistic: Average
    Period: 300
    EvaluationPeriods: 2
    Threshold: 2.0
    ComparisonOperator: GreaterThanThreshold
```

### Logging and Debugging

**Karpenter Logs**:
```bash
kubectl logs -n karpenter deployment/karpenter -f
```

**AWS Load Balancer Controller Logs**:
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller -f
```

**TargetGroupBinding Events**:
```bash
kubectl describe targetgroupbinding wordpress-tgb -n wordpress
```

## Best Practices

### Resource Planning
- Set appropriate CPU/memory requests to trigger Karpenter scaling
- Use resource limits to prevent resource contention
- Configure HPA with appropriate metrics and thresholds

### Node Configuration
- Use diverse instance types for better spot availability
- Configure appropriate subnet and security group selectors
- Set reasonable consolidation and expiration policies

### Monitoring
- Monitor both Kubernetes and AWS metrics
- Set up alerts for scaling events and failures
- Track cost implications of scaling decisions

### Testing
- Test scaling scenarios in non-production environments
- Validate behavior during spot instance interruptions
- Verify target registration/deregistration timing

## Troubleshooting

### Common Issues

**Pods Not Scheduling on New Nodes**
- Check node selectors and affinity rules
- Verify taints and tolerations configuration
- Confirm resource requests match node capacity

**Targets Not Registering**
- Verify TargetGroupBinding configuration
- Check AWS Load Balancer Controller permissions
- Confirm security group rules allow ALB → pod communication

**Slow Scaling Response**
- Review Karpenter provisioning logs
- Check EC2 instance launch times
- Verify subnet and security group availability

**High Costs from Over-Scaling**
- Tune HPA metrics and thresholds
- Adjust Karpenter consolidation policies
- Monitor instance type selection and spot usage

### Debugging Commands

```bash
# Check Karpenter status
kubectl get nodepools
kubectl get ec2nodeclasses
kubectl describe nodepool wordpress-nodepool

# Check node provisioning
kubectl get nodes -l karpenter.sh/provisioner-name
kubectl describe node <node-name>

# Check pod scheduling
kubectl get pods -n wordpress -o wide
kubectl describe pod <pod-name> -n wordpress

# Check target group registration
aws elbv2 describe-target-health --target-group-arn <arn>
```

## Cost Optimization

### Spot Instance Usage
- Configure Karpenter to prefer spot instances
- Use diverse instance types for better spot availability
- Monitor spot interruption rates and adjust accordingly

### Right-Sizing
- Use Vertical Pod Autoscaler (VPA) recommendations
- Monitor actual resource usage vs. requests
- Adjust instance type selection based on workload patterns

### Consolidation
- Enable Karpenter consolidation for cost savings
- Set appropriate consolidation delays
- Monitor consolidation events and their impact

This integration provides automatic, cost-effective scaling while maintaining high availability and performance for the WordPress application.
# TargetGroupBinding Configuration

This document explains the TargetGroupBinding configuration used in the WordPress on EKS platform to connect the standalone ALB with WordPress pods.

## Overview

TargetGroupBinding is a Custom Resource Definition (CRD) provided by the AWS Load Balancer Controller that allows Kubernetes services to register with existing AWS Application Load Balancer target groups. This enables a hybrid approach where:

- **Infrastructure Stack**: Creates and manages the ALB and target group via Terraform
- **Application Stack**: Uses TargetGroupBinding to register pod IPs with the pre-created target group

## Architecture Benefits

### Eliminates Circular Dependencies
- ALB and Route53 records are created in the same Terraform apply
- No need for two-phase deployment (ALB creation → Route53 record creation)
- Predictable infrastructure provisioning

### Supports Dynamic Scaling
- Automatically registers/deregisters pod IPs as pods scale up/down
- Works seamlessly with Horizontal Pod Autoscaler (HPA)
- Integrates with Karpenter node scaling (pods on new nodes are automatically registered)

### Maintains Kubernetes-Native Operations
- Uses standard Kubernetes Service (ClusterIP)
- Leverages Kubernetes readiness probes for health checks
- No NodePort complexity or port management

## Configuration

### Infrastructure Stack (Terraform)

The infrastructure stack creates the target group with IP target type:

```hcl
resource "aws_lb_target_group" "wordpress" {
  name        = "${var.name}-tg"
  port        = 80  # Pod port (WordPress container port)
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"  # Critical: must be "ip" for pod IP registration

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
  }

  deregistration_delay = 30

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-tg"
    }
  )
}
```

### Application Stack (Kubernetes)

The application stack creates the TargetGroupBinding resource:

```yaml
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: wordpress-tgb
  namespace: wordpress
spec:
  serviceRef:
    name: wordpress  # References the WordPress ClusterIP service
    port: 80         # Service port
  targetGroupARN: arn:aws:elasticloadbalancing:region:account:targetgroup/name/id
  targetType: ip
  networking:
    ingress:
      - from:
          - securityGroup:
              groupID: sg-xxxxx  # ALB security group ID
        ports:
          - protocol: TCP
            port: 8080  # WordPress container port
```

### WordPress Service Configuration

The WordPress service remains a standard ClusterIP service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: wordpress
  namespace: wordpress
spec:
  type: ClusterIP  # Standard ClusterIP, no LoadBalancer needed
  selector:
    app: wordpress
  ports:
    - name: http
      port: 80
      targetPort: 8080  # WordPress container port
      protocol: TCP
```

## Key Configuration Parameters

### targetGroupARN
- **Source**: Output from infrastructure stack Terraform
- **Format**: `arn:aws:elasticloadbalancing:region:account:targetgroup/name/id`
- **Critical**: Must match exactly the target group created by Terraform

### targetType
- **Value**: `ip`
- **Purpose**: Registers pod IPs directly (not node IPs)
- **Requirement**: Target group must also be configured with `target_type = "ip"`

### serviceRef
- **name**: Name of the Kubernetes service to bind
- **port**: Service port (not container port)
- **namespace**: Inherited from TargetGroupBinding metadata

### networking.ingress
- **Optional**: Can be managed by Terraform security group rules instead
- **Purpose**: Allows ALB security group to reach pods
- **Alternative**: Use separate `aws_security_group_rule` resources in Terraform

## Health Check Behavior

### Target Health Determination
1. **Kubernetes Readiness Probe**: Pod must pass readiness probe to be considered ready
2. **ALB Health Check**: Target group performs additional health checks on registered pod IPs
3. **Combined Logic**: Pod must be both Kubernetes-ready AND ALB-healthy to receive traffic

### Health Check Configuration
- **Path**: `/` (WordPress homepage)
- **Interval**: 30 seconds
- **Timeout**: 5 seconds
- **Healthy Threshold**: 2 consecutive successes
- **Unhealthy Threshold**: 2 consecutive failures

### Failure Scenarios
- **Pod Not Ready**: TargetGroupBinding won't register the pod IP
- **Pod Ready but ALB Unhealthy**: Pod IP registered but marked unhealthy in target group
- **Network Issues**: Security group rules may block ALB → pod communication

## Scaling Integration

### Horizontal Pod Autoscaler (HPA)
1. HPA scales WordPress deployment based on CPU/memory metrics
2. New pods are created and pass readiness probes
3. TargetGroupBinding automatically registers new pod IPs
4. ALB health checks validate new targets
5. Traffic is distributed to all healthy targets

### Karpenter Node Scaling
1. Karpenter provisions new nodes when pods can't be scheduled
2. Pods are scheduled on new nodes
3. TargetGroupBinding registers pod IPs regardless of which node they're on
4. No manual target group updates required

### Pod Termination
1. Pod receives SIGTERM signal
2. Pod is marked as not ready (fails readiness probe)
3. TargetGroupBinding deregisters pod IP from target group
4. ALB stops sending new requests to the pod
5. Existing connections are drained (deregistration delay: 30 seconds)
6. Pod is terminated after graceful shutdown

## Security Considerations

### Network Security
- ALB security group must allow outbound traffic to worker nodes on pod port
- Worker node security group must allow inbound traffic from ALB security group
- TargetGroupBinding can optionally manage these rules via `networking.ingress`

### IAM Permissions
AWS Load Balancer Controller requires these permissions for TargetGroupBinding:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:ModifyTargetGroup"
      ],
      "Resource": "*"
    }
  ]
}
```

## Troubleshooting

### Common Issues

**TargetGroupBinding Not Creating Targets**
- Check AWS Load Balancer Controller is running
- Verify IRSA role has target group permissions
- Confirm target group ARN is correct

**Targets Registered but Unhealthy**
- Verify security group rules allow ALB → pod communication
- Check WordPress pod readiness probe configuration
- Validate health check path returns 200 status

**Targets Not Deregistering**
- Check if pods are terminating gracefully
- Verify deregistration delay configuration
- Monitor AWS Load Balancer Controller logs

### Debugging Commands

```bash
# Check TargetGroupBinding status
kubectl get targetgroupbinding -n wordpress
kubectl describe targetgroupbinding wordpress-tgb -n wordpress

# Check AWS Load Balancer Controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check target group health in AWS
aws elbv2 describe-target-health --target-group-arn <arn>

# Check service endpoints
kubectl get endpoints -n wordpress
kubectl describe service wordpress -n wordpress
```

## Best Practices

### Configuration
- Always use `targetType: ip` for pod-based workloads
- Set appropriate deregistration delay (30-60 seconds)
- Configure health check parameters based on application startup time
- Use security group references instead of CIDR blocks

### Monitoring
- Monitor target group health metrics in CloudWatch
- Set up alarms for unhealthy target count
- Track target registration/deregistration events
- Monitor AWS Load Balancer Controller logs

### Operations
- Test scaling scenarios in non-production environments
- Verify health check behavior during deployments
- Document target group ARN for disaster recovery
- Keep AWS Load Balancer Controller updated

## Migration from Ingress

When migrating from Ingress-based ALB to TargetGroupBinding:

1. **Preparation**
   - Deploy infrastructure stack with standalone ALB
   - Note target group ARN from Terraform outputs
   - Ensure AWS Load Balancer Controller is still deployed

2. **Application Update**
   - Remove Ingress resources from WordPress Helm values
   - Add TargetGroupBinding resource with correct target group ARN
   - Keep service as ClusterIP (no changes needed)

3. **Verification**
   - Confirm targets are registered in AWS console
   - Test traffic flow through new ALB
   - Verify health checks are passing

4. **Cleanup**
   - Remove old Ingress resources
   - Clean up any orphaned ALB resources
   - Update monitoring and alerting

This approach provides a smooth migration path while maintaining service availability.
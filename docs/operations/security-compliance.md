# Security and Compliance

This document covers security and compliance features for the WordPress EKS platform monitoring system.

## Overview

The observability module implements comprehensive security and compliance features including:

- KMS encryption for persistent storage
- TLS encryption for metric communications
- PII scrubbing for collected metrics
- Audit logging for monitoring system access
- RBAC policies for access control
- Network security policies

## Features

### 1. KMS Encryption for Persistent Storage

All persistent volumes (Prometheus, Grafana, AlertManager) use KMS-encrypted EBS volumes.

**Configuration:**
- Storage classes configured with `encrypted: true` and `kmsKeyId` parameters
- Audit logs stored in CloudWatch encrypted with KMS keys
- All data at rest is encrypted

**Validation:**
```bash
# Check storage class encryption
kubectl get storageclass prometheus-gp3 -o yaml | grep -A 5 parameters

# Verify EBS volume encryption
VOLUME_ID=$(kubectl get pvc -n observability <pvc-name> -o jsonpath='{.spec.volumeName}')
aws ec2 describe-volumes --volume-ids $VOLUME_ID --query 'Volumes[0].Encrypted'
```

### 2. TLS Encryption for Metric Communications

Automatic TLS certificate generation using cert-manager for secure communications.

**Components:**
- Certificates for Prometheus, Grafana, and AlertManager services
- Network policies to restrict communication to TLS-enabled endpoints
- Mutual TLS (mTLS) support for service-to-service communication

**Prerequisites:**
- cert-manager installed in cluster
- ClusterIssuer configured for certificate generation

**Validation:**
```bash
# List certificates
kubectl get certificate -n observability

# Check certificate status
kubectl describe certificate prometheus-server-tls -n observability

# Test TLS connection
kubectl port-forward -n observability svc/prometheus-kube-prometheus-prometheus 9090:9090
curl -k https://localhost:9090/-/healthy
```

### 3. PII Scrubbing for Collected Metrics

Configurable PII scrubbing rules prevent sensitive data from being stored in metrics.

**Features:**
- Scrubbing rules for common patterns (emails, SSNs, IP addresses)
- Prometheus relabel configurations to remove PII from metric labels
- Automatic redaction of user identifiable information
- Support for custom scrubbing patterns

**Configuration:**
```hcl
pii_scrubbing_rules = [
  {
    pattern     = "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b"
    replacement = "[EMAIL_REDACTED]"
    description = "Email addresses"
  }
]
```

**Validation:**
```bash
# Check PII scrubbing ConfigMaps
kubectl get configmap -n observability | grep pii

# Verify no PII in metrics
kubectl port-forward -n observability svc/prometheus-kube-prometheus-prometheus 9090:9090
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq '.data.result[].metric' | grep -E '@|[0-9]{3}-[0-9]{2}-[0-9]{4}'
```

### 4. Audit Logging for Monitoring System Access

Centralized audit logging tracks all access and changes to the monitoring system.

**Features:**
- CloudWatch log group for centralized audit logs
- Fluent Bit DaemonSet for log collection from monitoring components
- Configurable retention periods (default: 90 days)
- Audit logs include access events, configuration changes, and administrative actions

**Validation:**
```bash
# Verify log group exists
aws logs describe-log-groups --log-group-name-prefix /aws/eks/wordpress-eks/monitoring-audit

# Check audit collector status
kubectl get daemonset -n observability | grep audit-collector

# View audit logs
aws logs tail /aws/eks/wordpress-eks/monitoring-audit --follow
```

### 5. RBAC Policies for Access Control

Kubernetes RBAC policies enforce least-privilege access to monitoring resources.

**Default Roles:**
- **monitoring-viewer**: Read-only access to monitoring resources
- **monitoring-admin**: Full access to monitoring resources

**Configuration:**
```hcl
rbac_policies = {
  "developers-viewer" = {
    subjects = [
      {
        kind      = "Group"
        name      = "developers"
        namespace = "observability"
      }
    ]
    role_ref = {
      kind      = "Role"
      name      = "monitoring-viewer"
      api_group = "rbac.authorization.k8s.io"
    }
  }
}
```

**Validation:**
```bash
# List monitoring roles
kubectl get role -n observability | grep monitoring

# Test viewer permissions
kubectl auth can-i get pods -n observability --as=system:serviceaccount:observability:viewer

# Test viewer cannot delete
kubectl auth can-i delete pods -n observability --as=system:serviceaccount:observability:viewer
```

### 6. Network Security

Network policies restrict traffic between monitoring components.

**Features:**
- Network policies for Prometheus, Grafana, and AlertManager
- Pod Security Policies for enhanced container security
- Security contexts enforcing non-root users and read-only root filesystems

**Validation:**
```bash
# List network policies
kubectl get networkpolicy -n observability

# Check pod security contexts
kubectl get pod -n observability -l app=kube-prometheus-stack-prometheus \
  -o jsonpath='{.items[0].spec.securityContext}' | jq
```

## Validation

### Automated Validation Script

Use the provided validation script to check all security features:

```bash
./modules/observability/modules/security/validate.sh observability wordpress-eks
```

The script validates:
- TLS certificates are issued and ready
- Storage classes have encryption enabled
- PII scrubbing ConfigMaps are created
- Audit logging is configured
- RBAC roles and bindings exist
- Network policies are in place
- Pod security contexts are properly configured

### Manual Validation Checklist

- [ ] cert-manager is installed and running
- [ ] ClusterIssuer is configured
- [ ] TLS certificates are issued and ready
- [ ] Storage classes have encryption enabled
- [ ] PVCs are using encrypted volumes
- [ ] CloudWatch log group exists with KMS encryption
- [ ] PII scrubbing ConfigMaps are created
- [ ] Prometheus relabel configs are applied
- [ ] Audit collector DaemonSet is running
- [ ] Audit logs appear in CloudWatch
- [ ] Monitoring viewer role exists
- [ ] Monitoring admin role exists
- [ ] RBAC permissions work as expected
- [ ] Network policies are created
- [ ] Pods run as non-root users
- [ ] Security contexts are properly configured

## Testing

### Testing Framework Options

For automated testing of security features, consider:

1. **Pytest + Testinfra** (Recommended): Python-based testing framework
   - Easy to write and maintain
   - Good for Kubernetes/AWS testing
   - Fast setup (15 minutes)

2. **Terratest**: Go-based infrastructure testing
   - Native Terraform integration
   - Parallel test execution
   - Medium complexity (30 minutes setup)

3. **Checkov**: Static analysis for pre-deployment validation
   - Catch issues before deployment
   - Very fast setup (5 minutes)

See the testing guide in `modules/observability/modules/security/TESTING_GUIDE.md` for detailed setup instructions.

### Example Pytest Tests

```python
def test_tls_certificates_exist(namespace):
    """Verify TLS certificates are created"""
    result = subprocess.run(
        ['kubectl', 'get', 'certificate', '-n', namespace, '-o', 'json'],
        capture_output=True, text=True
    )
    certs = json.loads(result.stdout)
    cert_names = [c['metadata']['name'] for c in certs['items']]
    
    assert 'prometheus-server-tls' in cert_names
    assert 'grafana-tls' in cert_names

def test_storage_class_encryption():
    """Verify storage classes have encryption enabled"""
    result = subprocess.run(
        ['kubectl', 'get', 'storageclass', 'prometheus-gp3', '-o', 'json'],
        capture_output=True, text=True
    )
    sc = json.loads(result.stdout)
    
    assert sc['parameters']['encrypted'] == 'true'
    assert 'kmsKeyId' in sc['parameters']
```

## Compliance

This implementation helps meet the following compliance requirements:

- **GDPR**: PII scrubbing and data retention policies
- **HIPAA**: Encryption at rest and in transit, audit logging
- **SOC 2**: Access controls, audit trails, encryption
- **PCI DSS**: Network segmentation, encryption, access logging

## Security Best Practices

1. **Encryption at Rest**: All persistent storage is encrypted using KMS
2. **Encryption in Transit**: TLS 1.2+ for all communications
3. **Least Privilege**: RBAC policies enforce minimal required permissions
4. **Audit Trail**: All access and changes are logged to CloudWatch
5. **PII Protection**: Automatic scrubbing of sensitive data from metrics
6. **Network Isolation**: Network policies restrict traffic between components
7. **Container Security**: Non-root users, read-only filesystems, dropped capabilities

## Troubleshooting

### TLS Certificate Issues

If certificates are not being generated:

1. Check cert-manager is running:
   ```bash
   kubectl get pods -n cert-manager
   ```

2. Check ClusterIssuer status:
   ```bash
   kubectl get clusterissuer
   ```

3. Check certificate status:
   ```bash
   kubectl get certificate -n observability
   kubectl describe certificate <cert-name> -n observability
   ```

### Audit Logging Issues

If audit logs are not appearing in CloudWatch:

1. Check DaemonSet status:
   ```bash
   kubectl get daemonset -n observability
   kubectl describe daemonset audit-collector -n observability
   ```

2. Check pod logs:
   ```bash
   kubectl logs -n observability -l component=audit-collector
   ```

3. Verify IAM permissions for CloudWatch Logs

### PII Scrubbing Issues

If PII is still appearing in metrics:

1. Check ConfigMap:
   ```bash
   kubectl get configmap -n observability | grep pii
   kubectl describe configmap monitoring-security-prometheus-pii-relabel -n observability
   ```

2. Verify relabel configurations are applied to Prometheus

3. Test regex patterns against sample data

### RBAC Permission Issues

If RBAC permissions are not working:

1. Check role bindings:
   ```bash
   kubectl get rolebinding -n observability -o yaml
   ```

2. Verify service account:
   ```bash
   kubectl get sa -n observability
   ```

3. Ensure subject names match and namespace is correct

## Related Documentation

- [Observability Module](../modules/observability.md) - Main observability module documentation
- [HA/DR](./ha-dr.md) - High availability and disaster recovery
- [Network Resilience](./network-resilience.md) - Network partition handling
- [Alert Rules Reference](../reference/alert-rules.md) - Alert rule definitions
- [Dashboard Reference](../reference/dashboards.md) - Dashboard configurations

## References

- [Prometheus Security Best Practices](https://prometheus.io/docs/operating/security/)
- [Grafana Security](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [AWS KMS Encryption](https://docs.aws.amazon.com/kms/latest/developerguide/overview.html)

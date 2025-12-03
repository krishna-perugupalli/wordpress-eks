#!/bin/bash
#############################################
# Security Module Validation Script
# Validates that all security features are properly configured
#############################################

set -e

NAMESPACE="${1:-observability}"
CLUSTER_NAME="${2:-eks}"

echo "🔒 Validating Security and Compliance Features"
echo "================================================"
echo "Namespace: $NAMESPACE"
echo "Cluster: $CLUSTER_NAME"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check function
check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
        return 1
    fi
}

# Warning function
warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "1. Checking TLS Certificates..."
echo "--------------------------------"

# Check if cert-manager is installed
kubectl get deployment -n cert-manager cert-manager &>/dev/null
check "cert-manager is installed"

# Check certificates
kubectl get certificate -n "$NAMESPACE" prometheus-server-tls &>/dev/null
check "Prometheus TLS certificate exists"

kubectl get certificate -n "$NAMESPACE" grafana-tls &>/dev/null
check "Grafana TLS certificate exists"

kubectl get certificate -n "$NAMESPACE" alertmanager-tls &>/dev/null
check "AlertManager TLS certificate exists"

# Check certificate status
PROM_CERT_READY=$(kubectl get certificate -n "$NAMESPACE" prometheus-server-tls -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
if [ "$PROM_CERT_READY" = "True" ]; then
    check "Prometheus certificate is ready"
else
    warn "Prometheus certificate status: $PROM_CERT_READY"
fi

echo ""
echo "2. Checking PII Scrubbing Configuration..."
echo "-------------------------------------------"

# Check PII scrubbing ConfigMaps
kubectl get configmap -n "$NAMESPACE" | grep -q "pii-rules"
check "PII scrubbing rules ConfigMap exists"

kubectl get configmap -n "$NAMESPACE" | grep -q "pii-relabel"
check "Prometheus PII relabel ConfigMap exists"

# Check number of PII rules
PII_RULES=$(kubectl get configmap -n "$NAMESPACE" -l component=security -o name 2>/dev/null | wc -l)
echo "   Found $PII_RULES PII-related ConfigMaps"

echo ""
echo "3. Checking Audit Logging..."
echo "-----------------------------"

# Check CloudWatch log group
LOG_GROUP="/aws/eks/${CLUSTER_NAME}/monitoring-audit"
aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" &>/dev/null
check "CloudWatch audit log group exists"

# Check retention
RETENTION=$(aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --query 'logGroups[0].retentionInDays' --output text 2>/dev/null || echo "Unknown")
echo "   Audit log retention: $RETENTION days"

# Check audit collector DaemonSet
kubectl get daemonset -n "$NAMESPACE" | grep -q "audit-collector"
check "Audit collector DaemonSet exists"

# Check audit collector pods
AUDIT_PODS=$(kubectl get pods -n "$NAMESPACE" -l component=audit-collector --no-headers 2>/dev/null | wc -l)
echo "   Audit collector pods running: $AUDIT_PODS"

echo ""
echo "4. Checking RBAC Policies..."
echo "-----------------------------"

# Check monitoring roles
kubectl get role -n "$NAMESPACE" | grep -q "monitoring-viewer"
check "Monitoring viewer role exists"

kubectl get role -n "$NAMESPACE" | grep -q "monitoring-admin"
check "Monitoring admin role exists"

# Check role permissions
VIEWER_RULES=$(kubectl get role -n "$NAMESPACE" monitoring-viewer -o jsonpath='{.rules}' 2>/dev/null | jq length 2>/dev/null || echo "0")
ADMIN_RULES=$(kubectl get role -n "$NAMESPACE" monitoring-admin -o jsonpath='{.rules}' 2>/dev/null | jq length 2>/dev/null || echo "0")
echo "   Viewer role rules: $VIEWER_RULES"
echo "   Admin role rules: $ADMIN_RULES"

echo ""
echo "5. Checking Network Policies..."
echo "--------------------------------"

# Check network policies
kubectl get networkpolicy -n "$NAMESPACE" | grep -q "prometheus-ingress"
check "Prometheus network policy exists"

kubectl get networkpolicy -n "$NAMESPACE" | grep -q "grafana-ingress"
check "Grafana network policy exists"

echo ""
echo "6. Checking Storage Encryption..."
echo "----------------------------------"

# Check storage classes
kubectl get storageclass prometheus-gp3 &>/dev/null && \
    kubectl get storageclass prometheus-gp3 -o yaml | grep -q "encrypted.*true"
check "Prometheus storage class has encryption enabled"

kubectl get storageclass grafana-gp3 &>/dev/null && \
    kubectl get storageclass grafana-gp3 -o yaml | grep -q "encrypted.*true"
check "Grafana storage class has encryption enabled"

echo ""
echo "7. Checking Pod Security..."
echo "----------------------------"

# Check security contexts
PROM_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=kube-prometheus-stack-prometheus --no-headers 2>/dev/null | wc -l)
if [ "$PROM_PODS" -gt 0 ]; then
    PROM_POD=$(kubectl get pods -n "$NAMESPACE" -l app=kube-prometheus-stack-prometheus -o name 2>/dev/null | head -1)
    RUN_AS_USER=$(kubectl get "$PROM_POD" -n "$NAMESPACE" -o jsonpath='{.spec.securityContext.runAsUser}' 2>/dev/null || echo "Unknown")
    echo "   Prometheus runs as user: $RUN_AS_USER"
    if [ "$RUN_AS_USER" != "0" ] && [ "$RUN_AS_USER" != "Unknown" ]; then
        check "Prometheus runs as non-root user"
    else
        warn "Prometheus user ID: $RUN_AS_USER"
    fi
fi

GRAFANA_PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana --no-headers 2>/dev/null | wc -l)
if [ "$GRAFANA_PODS" -gt 0 ]; then
    GRAFANA_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana -o name 2>/dev/null | head -1)
    RUN_AS_USER=$(kubectl get "$GRAFANA_POD" -n "$NAMESPACE" -o jsonpath='{.spec.securityContext.runAsUser}' 2>/dev/null || echo "Unknown")
    echo "   Grafana runs as user: $RUN_AS_USER"
    if [ "$RUN_AS_USER" != "0" ] && [ "$RUN_AS_USER" != "Unknown" ]; then
        check "Grafana runs as non-root user"
    else
        warn "Grafana user ID: $RUN_AS_USER"
    fi
fi

echo ""
echo "8. Summary..."
echo "-------------"

# Count checks
TOTAL_CHECKS=15
echo "Validation complete!"
echo ""
echo "Next steps:"
echo "1. Review any warnings or failures above"
echo "2. Check certificate status: kubectl get certificate -n $NAMESPACE"
echo "3. View audit logs: aws logs tail $LOG_GROUP --follow"
echo "4. Test RBAC: kubectl auth can-i get pods -n $NAMESPACE --as=system:serviceaccount:$NAMESPACE:viewer"
echo ""
echo "For detailed information, see:"
echo "- README.md"
echo "- IMPLEMENTATION.md"
echo "- examples/complete.tf"

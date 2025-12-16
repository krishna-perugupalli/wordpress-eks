#!/bin/bash
# Alert Metric Validation Script
# 
# This script helps validate that all metrics referenced in alert rules
# are actually available in Prometheus.
#
# Usage:
#   ./validate-metrics.sh [prometheus-url]
#
# Example:
#   ./validate-metrics.sh http://localhost:9090

set -e

PROMETHEUS_URL="${1:-http://localhost:9090}"

echo "=================================================="
echo "Alert Metric Validation Script"
echo "=================================================="
echo "Prometheus URL: $PROMETHEUS_URL"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a metric exists
check_metric() {
    local metric=$1
    local description=$2
    
    # Query Prometheus for the metric
    response=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=${metric}" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    
    if [ "$response" = "success" ]; then
        echo -e "${GREEN}✓${NC} $description: $metric"
        return 0
    else
        echo -e "${RED}✗${NC} $description: $metric"
        return 1
    fi
}

# Function to check if a job is being scraped
check_job() {
    local job=$1
    local description=$2
    
    response=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=up{job=\"${job}\"}" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    
    if [ "$response" = "success" ]; then
        echo -e "${GREEN}✓${NC} $description: job=\"$job\""
        return 0
    else
        echo -e "${RED}✗${NC} $description: job=\"$job\""
        return 1
    fi
}

echo "Checking Prometheus connectivity..."
if ! curl -s "${PROMETHEUS_URL}/-/healthy" > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Cannot connect to Prometheus at $PROMETHEUS_URL${NC}"
    echo "Please ensure Prometheus is running and accessible."
    echo ""
    echo "To port-forward Prometheus:"
    echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
    exit 1
fi
echo -e "${GREEN}✓${NC} Prometheus is accessible"
echo ""

# Check scrape targets (jobs)
echo "=================================================="
echo "Checking Scrape Targets (Jobs)"
echo "=================================================="
check_job "wordpress-metrics" "WordPress Exporter"
check_job "yace" "YACE CloudWatch Exporter"
check_job "redis-exporter" "Redis Exporter"
check_job "mysql-exporter" "MySQL Exporter"
check_job "kubernetes-apiservers" "Kubernetes API Server"
echo ""

# Check WordPress metrics
echo "=================================================="
echo "Checking WordPress Exporter Metrics"
echo "=================================================="
check_metric "wordpress_http_requests_total" "HTTP Requests Total"
check_metric "wordpress_http_request_duration_seconds_bucket" "HTTP Request Duration (Histogram)"
check_metric "wordpress_active_users_total" "Active Users"
check_metric "wordpress_memory_usage_bytes" "Memory Usage"
check_metric "up{job=\"wordpress-metrics\"}" "WordPress Exporter Up Status"
echo ""

# Check Kubernetes metrics
echo "=================================================="
echo "Checking Kubernetes Platform Metrics"
echo "=================================================="
check_metric "node_cpu_seconds_total" "Node CPU Seconds"
check_metric "node_memory_MemTotal_bytes" "Node Memory Total"
check_metric "node_memory_MemAvailable_bytes" "Node Memory Available"
check_metric "kube_deployment_status_replicas" "Deployment Replicas"
check_metric "kube_deployment_status_replicas_available" "Deployment Available Replicas"
check_metric "kube_pod_container_status_restarts_total" "Pod Restart Count"
check_metric "kube_pod_status_phase" "Pod Status Phase"
check_metric "kube_node_status_condition" "Node Status Condition"
check_metric "kubelet_volume_stats_used_bytes" "PV Used Bytes"
check_metric "kubelet_volume_stats_capacity_bytes" "PV Capacity Bytes"
echo ""

# Check YACE AWS metrics
echo "=================================================="
echo "Checking YACE CloudWatch Metrics"
echo "=================================================="
check_metric "aws_rds_cpuutilization_average" "RDS CPU Utilization"
check_metric "aws_rds_database_connections_average" "RDS Database Connections"
check_metric "aws_rds_freeable_memory_average" "RDS Freeable Memory"
check_metric "aws_elasticache_cpuutilization_average" "ElastiCache CPU Utilization"
check_metric "aws_elasticache_database_memory_usage_percentage_average" "ElastiCache Memory Usage %"
check_metric "aws_elasticache_evictions_sum" "ElastiCache Evictions"
check_metric "aws_elasticache_curr_connections_average" "ElastiCache Current Connections"
check_metric "aws_alb_target_response_time_average" "ALB Target Response Time"
check_metric "aws_alb_httpcode_target_5xx_count_sum" "ALB Target 5XX Count"
check_metric "aws_alb_request_count_sum" "ALB Request Count"
check_metric "aws_alb_un_healthy_host_count_average" "ALB Unhealthy Host Count"
check_metric "aws_efs_data_read_iobytes_sum" "EFS Data Read IO Bytes"
check_metric "aws_efs_data_write_iobytes_sum" "EFS Data Write IO Bytes"
echo ""

# Check Karpenter metrics (optional)
echo "=================================================="
echo "Checking Karpenter Metrics (Optional)"
echo "=================================================="
if check_metric "karpenter_nodes_created_total" "Karpenter Nodes Created"; then
    check_metric "karpenter_pods_state" "Karpenter Pods State"
else
    echo -e "${YELLOW}⚠${NC}  Karpenter metrics not available - KarpenterNodeProvisioningFailures alert may not work"
fi
echo ""

# Summary
echo "=================================================="
echo "Validation Complete"
echo "=================================================="
echo ""
echo "Next steps:"
echo "1. Review any failed metric checks above"
echo "2. Verify ServiceMonitors are created: kubectl get servicemonitors -A"
echo "3. Check Prometheus targets: ${PROMETHEUS_URL}/targets"
echo "4. Verify PrometheusRules are loaded: kubectl get prometheusrules -A"
echo ""
echo "To test alert expressions in Prometheus UI:"
echo "  ${PROMETHEUS_URL}/graph"
echo ""

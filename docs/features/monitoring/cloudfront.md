# CloudFront CDN Monitoring

## Overview

CloudFront monitoring provides comprehensive visibility into CDN performance, cache efficiency, and content delivery metrics. Metrics are collected through the CloudWatch exporter and visualized in Grafana dashboards.

## Features

### Metrics Collected

The following CloudFront metrics are collected every 5 minutes:

| Metric | Type | Description |
|--------|------|-------------|
| `aws_cloudfront_requests_sum` | Counter | Total number of requests |
| `aws_cloudfront_bytes_downloaded_sum` | Counter | Total bytes downloaded |
| `aws_cloudfront_bytes_uploaded_sum` | Counter | Total bytes uploaded |
| `aws_cloudfront_4xx_error_rate_average` | Gauge | 4xx error rate percentage |
| `aws_cloudfront_5xx_error_rate_average` | Gauge | 5xx error rate percentage |
| `aws_cloudfront_total_error_rate_average` | Gauge | Total error rate percentage |
| `aws_cloudfront_cache_hit_rate_average` | Gauge | Cache hit rate percentage |
| `aws_cloudfront_origin_latency_average` | Gauge | Origin response latency in ms |

### Monitoring Capabilities

- **Request Metrics**: Total requests and request rates per distribution
- **Cache Performance**: Cache hit rates to measure CDN efficiency
- **Data Transfer**: Bytes downloaded and uploaded tracking
- **Error Rates**: 4xx and 5xx error rate monitoring
- **Origin Performance**: Origin latency measurements
- **Multi-Distribution Support**: Monitor multiple CloudFront distributions simultaneously

## Configuration

### Enable CloudFront Monitoring

In your Terraform Cloud workspace variables or `.tfvars` file:

```hcl
# Enable CloudFront monitoring
enable_cloudfront_monitoring = true

# Specify CloudFront distribution IDs to monitor
cloudfront_distribution_ids = [
  "E1234567890ABC",  # Production distribution
  "E0987654321XYZ"   # Staging distribution
]

# Ensure required components are enabled
enable_cloudwatch_exporter = true
enable_prometheus_stack    = true
enable_grafana             = true
```

### IAM Permissions

The CloudWatch exporter requires these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudfront:ListDistributions",
        "cloudfront:ListTagsForResource",
        "cloudfront:GetDistribution",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics"
      ],
      "Resource": "*"
    }
  ]
}
```

These permissions are automatically configured when CloudFront monitoring is enabled.

## Deployment

### Deploy the Configuration

```bash
# From stacks/app directory
make plan-app
make apply-app
```

### Verify Deployment

```bash
# Check CloudWatch exporter is running
kubectl get pods -n observability -l app=cloudwatch-exporter

# Check exporter logs
kubectl logs -n observability -l app=cloudwatch-exporter

# Verify distribution IDs are correct
aws cloudfront list-distributions --query 'DistributionList.Items[*].Id'
```

## Accessing Dashboards

### Port-Forward to Grafana

```bash
kubectl port-forward -n observability svc/grafana 3000:80
```

### Open Grafana

1. Open browser to `http://localhost:3000`
2. Login with configured credentials
3. Navigate to "AWS Services Monitoring" dashboard
4. View CloudFront panels

### Dashboard Panels

The AWS Services dashboard includes these CloudFront panels:

1. **CloudFront Request Rate**
   - Visualization: Time series
   - Shows requests per second per distribution
   - Useful for traffic pattern analysis

2. **CloudFront Cache Hit Rate**
   - Visualization: Time series with thresholds
   - Thresholds: Red < 70%, Yellow 70-90%, Green > 90%
   - Key metric for CDN efficiency

3. **CloudFront Origin Latency**
   - Visualization: Time series
   - Unit: Milliseconds
   - Thresholds: Green < 100ms, Yellow 100-500ms, Red > 500ms

4. **CloudFront Error Rates**
   - Visualization: Time series
   - Shows 4xx and 5xx error rates
   - Thresholds: Green < 1%, Yellow 1-5%, Red > 5%

5. **CloudFront Data Transfer**
   - Visualization: Time series
   - Shows bytes downloaded and uploaded
   - Rate calculation for throughput

## Metrics Interpretation

### Cache Hit Rate

**Target**: > 90% for optimal CDN performance

- **Green (> 90%)**: Excellent cache performance
- **Yellow (70-90%)**: Consider cache policy optimization
- **Red (< 70%)**: Review cache behaviors and TTL settings

**Optimization Tips**:
- Increase TTL for static content
- Review cache key parameters
- Check query string forwarding settings
- Verify cookie forwarding configuration

### Origin Latency

**Target**: < 100ms for good user experience

- **Green (< 100ms)**: Healthy origin performance
- **Yellow (100-500ms)**: Monitor origin server performance
- **Red (> 500ms)**: Investigate origin server issues

**Troubleshooting High Latency**:
- Check origin server health
- Review database query performance
- Verify network connectivity
- Check for origin server resource constraints

### Error Rates

**Target**: < 1% for healthy distribution

- **Green (< 1%)**: Normal operation
- **Yellow (1-5%)**: Review error patterns
- **Red (> 5%)**: Critical issue requiring immediate attention

**Common Causes**:
- **4xx Errors**: Client-side issues, missing content, authentication failures
- **5xx Errors**: Origin server errors, timeouts, capacity issues

### Request Rate

Monitor for:
- Traffic patterns and trends
- Anomalies and spikes
- Capacity planning needs
- DDoS attack indicators

## Querying Metrics

### Prometheus Queries

Access Prometheus at `http://localhost:9090` (after port-forward):

```promql
# Request rate per distribution
rate(aws_cloudfront_requests_sum[5m])

# Cache hit rate
aws_cloudfront_cache_hit_rate_average

# Origin latency
aws_cloudfront_origin_latency_average

# Error rate
aws_cloudfront_5xx_error_rate_average

# Data transfer rate
rate(aws_cloudfront_bytes_downloaded_sum[5m])
```

### Example Queries

**Top distributions by request rate**:
```promql
topk(5, rate(aws_cloudfront_requests_sum[5m]))
```

**Distributions with low cache hit rate**:
```promql
aws_cloudfront_cache_hit_rate_average < 70
```

**Distributions with high error rate**:
```promql
aws_cloudfront_5xx_error_rate_average > 5
```

## Integration with Existing Monitoring

CloudFront metrics integrate with other AWS service monitoring:

- **ALB Metrics**: Compare CloudFront requests with origin ALB requests
- **RDS Metrics**: Correlate CDN cache misses with database load
- **EFS Metrics**: Track static content delivery from EFS
- **Cost Monitoring**: CloudFront data transfer costs

## Alerting

### Recommended Alerts

Consider creating alerts for:

1. **Low Cache Hit Rate**
   ```promql
   aws_cloudfront_cache_hit_rate_average < 70
   ```

2. **High Error Rate**
   ```promql
   aws_cloudfront_5xx_error_rate_average > 5
   ```

3. **High Origin Latency**
   ```promql
   aws_cloudfront_origin_latency_average > 500
   ```

4. **Traffic Spikes**
   ```promql
   rate(aws_cloudfront_requests_sum[5m]) > 1000
   ```

### Alert Configuration

Alerts are configured in the Prometheus AlertManager. See [Alert Rules Reference](../../reference/alert-rules.md) for details.

## Troubleshooting

### No CloudFront Metrics Appearing

1. **Verify CloudWatch exporter is running**:
   ```bash
   kubectl get pods -n observability -l app=cloudwatch-exporter
   ```

2. **Check exporter logs**:
   ```bash
   kubectl logs -n observability -l app=cloudwatch-exporter
   ```

3. **Verify IAM permissions**:
   ```bash
   kubectl describe sa -n observability cloudwatch-exporter
   ```

4. **Confirm distribution IDs are correct**:
   ```bash
   aws cloudfront list-distributions --query 'DistributionList.Items[*].Id'
   ```

### Metrics Delayed

- CloudFront metrics have a 1-minute delay in CloudWatch
- Exporter scrapes every 5 minutes (300 seconds)
- Total delay: 1-6 minutes is normal

### Missing Specific Distribution

- Verify distribution ID is in `cloudfront_distribution_ids` variable
- Check distribution is in the same AWS account
- Ensure distribution is enabled and deployed
- Verify distribution has recent traffic

### High CloudWatch API Costs

- CloudWatch API calls are rate-limited
- Exporter uses intelligent caching (600-second range)
- Multiple distributions share the same scrape interval
- Consider reducing scrape frequency if costs are high

## Performance Considerations

### Resource Usage

**CloudWatch Exporter**:
- CPU: 100m request, 500m limit
- Memory: 256Mi request, 1Gi limit
- Minimal impact on cluster resources

### Network Bandwidth

- CloudWatch API calls: ~1-5 requests per scrape
- Metric data: ~10-50 KB per distribution per scrape
- Negligible network impact

### CloudFront Impact

- No performance impact on CloudFront distributions
- Metrics collection is read-only
- No additional latency for end users

## Security

### IAM Roles

- Uses IRSA for AWS credentials (no static keys)
- Read-only CloudWatch and CloudFront permissions
- Least privilege access model

### Data Privacy

- Metrics do not contain PII
- No request content is collected
- Only aggregate statistics are stored

### Encryption

- TLS encryption for metric transmission (when security module enabled)
- Metrics stored in Prometheus with optional encryption at rest

## Cost Optimization

### CloudWatch API Costs

- **GetMetricStatistics**: $0.01 per 1,000 requests
- **ListMetrics**: $0.01 per 1,000 requests
- **Typical Cost**: $1-5/month for 5 distributions

### Optimization Tips

- Monitor only active distributions
- Adjust scrape interval if needed
- Use CloudWatch metric filters
- Consider CloudWatch Logs Insights for detailed analysis

## Future Enhancements

Potential improvements for future iterations:

1. **Real-time Logs**: CloudFront real-time log streaming
2. **Geographic Metrics**: Per-region performance tracking
3. **Custom Metrics**: CloudFront Functions execution metrics
4. **Cost Attribution**: Per-distribution cost tracking
5. **Cache Invalidation Tracking**: Monitor invalidation patterns
6. **Lambda@Edge Metrics**: Edge function performance

## Validation

### Check Prometheus Targets

```bash
# Port-forward to Prometheus
kubectl port-forward -n observability svc/prometheus-kube-prometheus-prometheus 9090:9090

# Visit http://localhost:9090/targets
# Look for cloudwatch-exporter target
```

### Query CloudFront Metrics

```promql
# Check if metrics are being collected
aws_cloudfront_requests_sum

# Check cache hit rate
aws_cloudfront_cache_hit_rate_average

# Check for all distributions
count(aws_cloudfront_requests_sum) by (distribution_id)
```

### Verify Grafana Dashboard

1. Open AWS Services dashboard
2. Confirm CloudFront panels display data
3. Check for proper legend labels with distribution IDs
4. Verify time range selector works correctly

## Related Documentation

- [Observability Module Guide](../../modules/observability.md)
- [Monitoring Overview](./README.md)
- [Grafana Dashboards](./grafana.md)
- [AWS Services Monitoring](../../reference/dashboards.md)
- [AWS CloudFront Metrics Reference](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/monitoring-using-cloudwatch.html)

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review CloudWatch exporter logs
3. Verify IAM permissions
4. Contact platform team

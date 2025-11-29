# AlertManager and Alert Routing

## Overview

AlertManager handles alerts sent by Prometheus and other monitoring systems. It provides intelligent alert routing, grouping, deduplication, and notification delivery through multiple channels including email, Slack, PagerDuty, and AWS SNS.

## Features

- **Intelligent Alert Routing**: Route alerts based on severity, component, and team ownership
- **Alert Grouping**: Group related alerts to reduce notification noise
- **Deduplication**: Prevent duplicate notifications for the same alert
- **Inhibition Rules**: Suppress alerts when related critical alerts are firing
- **Multiple Notification Channels**: Email, Slack, PagerDuty, SNS
- **High Availability**: Multi-replica deployment with gossip protocol
- **Persistent Storage**: Alert state persists across pod restarts
- **IRSA Integration**: Secure AWS SNS access without static credentials

## Prerequisites

- Prometheus stack deployed and collecting metrics
- Alert rules configured in Prometheus
- Notification channel credentials (SMTP, Slack webhook, PagerDuty key, SNS topic)
- EKS cluster with OIDC provider configured

## Configuration

### Basic Configuration

Enable AlertManager in your Terraform Cloud workspace variables:

```hcl
# Enable AlertManager
enable_alertmanager = true

# Storage configuration
alertmanager_storage_size  = "10Gi"
alertmanager_storage_class = "gp3"
alertmanager_replica_count = 2

# Basic notification (SNS)
sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:monitoring-alerts"
```

### Production Configuration

For production environments with multiple notification channels:

```hcl
# Enable AlertManager
enable_alertmanager = true

# High availability
alertmanager_replica_count = 3
alertmanager_storage_size  = "20Gi"

# Resource allocation
alertmanager_resource_requests = {
  cpu    = "200m"
  memory = "256Mi"
}

alertmanager_resource_limits = {
  cpu    = "1"
  memory = "1Gi"
}

# Notification channels
sns_topic_arn             = "arn:aws:sns:us-east-1:123456789012:monitoring-alerts"
slack_webhook_url         = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
pagerduty_integration_key = "your-pagerduty-integration-key"

# SMTP configuration for email
smtp_config = {
  host          = "smtp.example.com:587"
  user          = "alerts@example.com"
  password      = "smtp-password"
  from_address  = "alerts@example.com"
  from_name     = "WordPress EKS Alerts"
  require_tls   = true
}

# Alert routing
alert_routing_config = {
  group_by        = ["alertname", "cluster", "service"]
  group_wait      = "10s"
  group_interval  = "10s"
  repeat_interval = "1h"
  routes = [
    {
      match = {
        severity = "critical"
      }
      receiver = "pagerduty"
      continue = true
    },
    {
      match = {
        severity = "warning"
      }
      receiver = "slack"
      continue = false
    }
  ]
}
```

### Development Configuration

For development/testing environments:

```hcl
# Enable AlertManager
enable_alertmanager = true

# Minimal resources
alertmanager_replica_count = 1
alertmanager_storage_size  = "5Gi"

# Single notification channel (email)
smtp_config = {
  host          = "smtp.example.com:587"
  user          = "dev-alerts@example.com"
  password      = "smtp-password"
  from_address  = "dev-alerts@example.com"
  from_name     = "Dev Alerts"
}
```

## Deployment

### Step 1: Set Up Notification Channels

#### SNS Topic

Create SNS topic for alerts:

```bash
aws sns create-topic --name monitoring-alerts --region us-east-1

# Subscribe email to topic
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:123456789012:monitoring-alerts \
  --protocol email \
  --notification-endpoint ops-team@example.com
```

#### Slack Webhook

1. Go to your Slack workspace settings
2. Create an incoming webhook
3. Copy the webhook URL
4. Add to Terraform Cloud variables

#### PagerDuty Integration

1. Create a PagerDuty service
2. Add Prometheus integration
3. Copy the integration key
4. Add to Terraform Cloud variables

### Step 2: Configure Variables

Set the required variables in your Terraform Cloud workspace (see Configuration section above).

### Step 3: Deploy

```bash
cd stacks/app
make plan-app
make apply-app
```

### Step 4: Verify Deployment

```bash
# Check AlertManager pods
kubectl get pods -n observability -l app=alertmanager

# Check AlertManager service
kubectl get svc -n observability alertmanager

# Check persistent volumes
kubectl get pvc -n observability -l app=alertmanager
```

## Accessing AlertManager

### Port Forward

```bash
kubectl port-forward -n observability svc/alertmanager 9093:9093
```

Then access at: http://localhost:9093

### AlertManager UI

The UI provides:
- **Alerts**: View all active alerts
- **Silences**: Create and manage alert silences
- **Status**: View AlertManager configuration and status

## Alert Routing

### Default Routing Logic

AlertManager routes alerts based on labels and severity:

1. **Critical Alerts** (severity=critical)
   - Sent to: PagerDuty, Slack, Email, SNS
   - Group wait: 10 seconds
   - Repeat interval: 30 minutes

2. **Warning Alerts** (severity=warning)
   - Sent to: Slack, Email
   - Group wait: 30 seconds
   - Repeat interval: 2 hours

3. **Info Alerts** (severity=info)
   - Sent to: Email only
   - Group wait: 5 minutes
   - Repeat interval: 12 hours

### Component-Specific Routing

Route alerts based on component:

```hcl
alert_routing_config = {
  routes = [
    {
      match = {
        component = "wordpress"
      }
      receiver = "wordpress-team"
    },
    {
      match = {
        component = "database"
      }
      receiver = "database-team"
    },
    {
      match = {
        component = "infrastructure"
      }
      receiver = "platform-team"
    }
  ]
}
```

### Custom Routing Rules

Create custom routing based on any label:

```hcl
alert_routing_config = {
  routes = [
    {
      match = {
        team = "frontend"
      }
      match_re = {
        service = "wordpress.*"
      }
      receiver = "frontend-team"
      group_by = ["alertname", "service"]
      continue = false
    }
  ]
}
```

## Notification Channels

### Email (SMTP)

Configure SMTP for email notifications:

```hcl
smtp_config = {
  host          = "smtp.gmail.com:587"
  user          = "alerts@example.com"
  password      = "app-password"
  from_address  = "alerts@example.com"
  from_name     = "WordPress EKS Monitoring"
  require_tls   = true
}
```

**Email Template** includes:
- Alert status (firing/resolved)
- Cluster and alert name
- Summary and description
- Runbook links
- Separate sections for firing and resolved alerts

### Slack

Configure Slack webhook:

```hcl
slack_webhook_url = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX"
```

**Slack Message** includes:
- Alert severity and name
- Cluster information
- Summary and description
- Runbook links
- Color-coded by severity (red=critical, yellow=warning)

### PagerDuty

Configure PagerDuty integration:

```hcl
pagerduty_integration_key = "your-32-character-integration-key"
```

**PagerDuty Incident** includes:
- Alert description
- Firing and resolved counts
- Cluster, severity, and component labels
- Automatic resolution when alerts clear

### AWS SNS

Configure SNS topic:

```hcl
sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:monitoring-alerts"
```

**SNS Message** includes:
- Alert name and cluster
- Severity level
- Summary and description
- Runbook links

SNS can fan out to:
- Email subscriptions
- SMS subscriptions
- Lambda functions
- SQS queues
- HTTP/HTTPS endpoints

## Alert Grouping

### Group By Labels

Group related alerts together:

```hcl
alert_routing_config = {
  group_by = ["alertname", "cluster", "service"]
}
```

This groups alerts with the same:
- Alert name
- Cluster
- Service

### Group Timing

Control when grouped alerts are sent:

```hcl
alert_routing_config = {
  group_wait      = "10s"   # Wait before sending first notification
  group_interval  = "10s"   # Wait before sending updates
  repeat_interval = "1h"    # Wait before resending
}
```

## Inhibition Rules

Inhibition rules suppress alerts when related critical alerts are firing.

### Default Inhibition

Critical alerts inhibit warning alerts for the same:
- Alert name
- Cluster
- Service

Example: If `DatabaseDown` (critical) is firing, suppress `DatabaseSlowQueries` (warning).

### Custom Inhibition

Create custom inhibition rules:

```hcl
inhibition_rules = [
  {
    source_match = {
      severity = "critical"
      alertname = "NodeDown"
    }
    target_match = {
      severity = "warning"
    }
    target_match_re = {
      alertname = "Node.*"
    }
    equal = ["cluster", "instance"]
  }
]
```

## Silences

### Creating Silences

Silence alerts temporarily via UI or API:

```bash
# Via amtool CLI
amtool silence add \
  alertname=HighMemoryUsage \
  cluster=production \
  --duration=2h \
  --comment="Planned maintenance"
```

### Silence Patterns

Silence by:
- Alert name
- Severity
- Component
- Any label combination

### Silence Management

- View active silences in UI
- Expire silences early
- Extend silence duration
- Add comments for context

## High Availability

### Multi-Replica Deployment

AlertManager runs with multiple replicas:

```hcl
alertmanager_replica_count = 3
```

### Gossip Protocol

Replicas communicate via gossip protocol:
- Share alert state
- Deduplicate notifications
- Coordinate silences

### Pod Anti-Affinity

Replicas spread across nodes:
- Prevents single point of failure
- Survives node failures
- Maintains availability during updates

### Persistent Storage

Alert state persists to EBS volumes:
- Survives pod restarts
- Maintains silences
- Preserves notification history

## Monitoring AlertManager

### Key Metrics

Monitor these AlertManager metrics:

- `alertmanager_alerts`: Number of active alerts
- `alertmanager_alerts_received_total`: Total alerts received
- `alertmanager_notifications_total`: Total notifications sent
- `alertmanager_notifications_failed_total`: Failed notifications
- `alertmanager_silences`: Number of active silences

### Health Check

Check AlertManager health:

```bash
kubectl exec -n observability deployment/alertmanager -- \
  curl -s http://localhost:9093/-/healthy
```

### Resource Usage

Monitor resource consumption:

```bash
kubectl top pod -n observability -l app=alertmanager
```

## Troubleshooting

### Alerts Not Firing

Check Prometheus configuration:

```bash
# Verify AlertManager is configured in Prometheus
kubectl get prometheus -n observability -o yaml | grep alertmanagers
```

Check alert rules:

```bash
# List all PrometheusRule resources
kubectl get prometheusrules -A
```

### Notifications Not Sent

Check AlertManager logs:

```bash
kubectl logs -n observability deployment/alertmanager
```

Test notification channel:

```bash
# Send test alert
amtool alert add test_alert \
  severity=warning \
  summary="Test alert" \
  --alertmanager.url=http://localhost:9093
```

### IRSA Permission Issues

Verify IAM role:

```bash
# Check service account annotation
kubectl get sa -n observability alertmanager -o yaml

# Check IAM role
aws iam get-role --role-name <cluster-name>-alertmanager
```

### Replicas Not Communicating

Check gossip protocol:

```bash
# View cluster status
kubectl exec -n observability alertmanager-0 -- \
  amtool cluster show --alertmanager.url=http://localhost:9093
```

### Storage Issues

Check persistent volumes:

```bash
kubectl get pvc -n observability -l app=alertmanager
kubectl describe pvc <pvc-name> -n observability
```

## Testing Alerts

### Send Test Alert

```bash
# Port-forward to AlertManager
kubectl port-forward -n observability svc/alertmanager 9093:9093

# Send test alert via amtool
amtool alert add test_alert \
  severity=warning \
  cluster=production \
  summary="This is a test alert" \
  description="Testing alert routing" \
  --alertmanager.url=http://localhost:9093
```

### Verify Notification

Check that notification was sent to configured channels:
- Email inbox
- Slack channel
- PagerDuty incidents
- SNS topic subscriptions

## Best Practices

### Alert Design

1. **Use Meaningful Names**: Clear, descriptive alert names
2. **Include Context**: Add labels for routing and grouping
3. **Set Appropriate Severity**: Critical, Warning, Info
4. **Add Runbook Links**: Include troubleshooting steps
5. **Test Alerts**: Verify alerts fire correctly

### Notification Management

1. **Avoid Alert Fatigue**: Don't over-alert
2. **Use Inhibition**: Prevent alert storms
3. **Group Related Alerts**: Reduce notification noise
4. **Set Appropriate Intervals**: Balance urgency and noise
5. **Use Silences**: For planned maintenance

### Routing Strategy

1. **Route by Severity**: Critical to on-call, warnings to Slack
2. **Route by Component**: Team-specific channels
3. **Use Continue Flag**: Send to multiple receivers when needed
4. **Test Routing**: Verify alerts reach correct channels
5. **Document Routes**: Maintain routing documentation

## Security Considerations

1. **Use IRSA**: Avoid static AWS credentials
2. **Encrypt Storage**: Use KMS for persistent volumes
3. **Secure Webhooks**: Use HTTPS for Slack/PagerDuty
4. **Rotate Credentials**: Regularly rotate SMTP passwords
5. **Restrict Access**: Limit who can create silences
6. **Audit Logging**: Enable audit logs for compliance

## Advanced Configuration

### Custom Receivers

Define custom notification receivers:

```hcl
custom_receivers = [
  {
    name = "custom-webhook"
    webhook_configs = [
      {
        url = "https://example.com/webhook"
        send_resolved = true
      }
    ]
  }
]
```

### Time-Based Routing

Route alerts differently based on time:

```hcl
alert_routing_config = {
  routes = [
    {
      match = {
        severity = "warning"
      }
      receiver = "business-hours"
      active_time_intervals = ["business-hours"]
    }
  ]
}

time_intervals = [
  {
    name = "business-hours"
    time_intervals = [
      {
        weekdays = ["monday:friday"]
        times = [
          {
            start_time = "09:00"
            end_time = "17:00"
          }
        ]
      }
    ]
  }
]
```

### Custom Templates

Override notification templates:

```hcl
custom_templates = {
  "email.tmpl" = file("${path.module}/templates/email.tmpl")
  "slack.tmpl" = file("${path.module}/templates/slack.tmpl")
}
```

## Integration with Grafana

View AlertManager alerts in Grafana:

1. Add AlertManager as a data source
2. Create alert list panels
3. Display notification history
4. Visualize alert trends

## Related Documentation

- [Enhanced Monitoring Overview](./README.md)
- [Prometheus Configuration](./prometheus.md)
- [Grafana Dashboards](./grafana.md)
- [Alert Rules Reference](../../reference/alert-rules.md)
- [Variables Reference](../../reference/variables.md)

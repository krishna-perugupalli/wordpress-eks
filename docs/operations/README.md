# Operations Documentation

Day-2 operations guides, runbooks, and procedures for maintaining the WordPress EKS platform.

## Available Guides

### High Availability & Resilience
- [HA/DR](ha-dr.md) - High availability and disaster recovery procedures
- [Network Resilience](network-resilience.md) - Network partition handling and recovery

### Security & Compliance
- [Security Compliance](security-compliance.md) - Security validation and compliance checks

### Cost & Optimization
- [Cost Optimization](cost-optimization.md) - Cost monitoring and optimization strategies

### Backup & Recovery
- [Backup & Restore](backup-restore.md) - Backup procedures and restore operations

### Troubleshooting
- [Troubleshooting](troubleshooting.md) - Common issues and solutions

## Operations Documentation Structure

Each operational guide includes:
- **Purpose**: What operational concern it addresses
- **Procedures**: Step-by-step operational procedures
- **Runbooks**: Incident response and troubleshooting steps
- **Validation**: How to verify operations completed successfully
- **Rollback**: How to revert changes if needed

## Quick Reference

### Common Operations
- Check cluster health: `kubectl get nodes`
- View pod status: `kubectl get pods -A`
- Check Aurora status: AWS Console → RDS
- Review logs: CloudWatch Logs or Fluent Bit
- Monitor costs: AWS Cost Explorer or Grafana cost dashboard

### Emergency Contacts
- Define your escalation procedures
- Document on-call rotation
- Maintain incident response playbooks

## Related Documentation

- [Architecture](../architecture.md) - System design and component relationships
- [Runbook](../runbook.md) - General operational runbook
- [Modules](../modules/) - Module-specific technical details
- [Features](../features/) - Feature configuration and usage

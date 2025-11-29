-- MySQL monitoring user setup script
-- Creates a dedicated monitoring user with minimal privileges for metrics collection

-- Create monitoring user with minimal privileges
CREATE USER IF NOT EXISTS 'monitoring'@'%' IDENTIFIED BY 'MONITORING_PASSWORD_PLACEHOLDER';

-- Grant minimal required privileges for metrics collection
GRANT PROCESS ON *.* TO 'monitoring'@'%';
GRANT REPLICATION CLIENT ON *.* TO 'monitoring'@'%';
GRANT SELECT ON performance_schema.* TO 'monitoring'@'%';
GRANT SELECT ON information_schema.* TO 'monitoring'@'%';

-- Grant specific privileges for detailed metrics
GRANT SELECT ON mysql.user TO 'monitoring'@'%';
GRANT SELECT ON mysql.* TO 'monitoring'@'%';

-- Grant privileges for InnoDB metrics
GRANT SELECT ON information_schema.INNODB_METRICS TO 'monitoring'@'%';
GRANT SELECT ON information_schema.INNODB_SYS_TABLESTATS TO 'monitoring'@'%';
GRANT SELECT ON information_schema.INNODB_CMP TO 'monitoring'@'%';
GRANT SELECT ON information_schema.INNODB_CMP_RESET TO 'monitoring'@'%';

-- Grant privileges for performance schema metrics
GRANT SELECT ON performance_schema.table_io_waits_summary_by_table TO 'monitoring'@'%';
GRANT SELECT ON performance_schema.table_lock_waits_summary_by_table TO 'monitoring'@'%';
GRANT SELECT ON performance_schema.index_io_waits_summary_by_table TO 'monitoring'@'%';
GRANT SELECT ON performance_schema.events_waits_summary_global_by_event_name TO 'monitoring'@'%';
GRANT SELECT ON performance_schema.file_summary_by_event_name TO 'monitoring'@'%';
GRANT SELECT ON performance_schema.file_summary_by_instance TO 'monitoring'@'%';
GRANT SELECT ON performance_schema.replication_group_member_stats TO 'monitoring'@'%';
GRANT SELECT ON performance_schema.replication_group_members TO 'monitoring'@'%';

-- Grant privileges for query response time metrics (if available)
GRANT SELECT ON information_schema.QUERY_RESPONSE_TIME TO 'monitoring'@'%';

-- Grant privileges for processlist monitoring
GRANT SELECT ON information_schema.PROCESSLIST TO 'monitoring'@'%';

-- Grant privileges for table statistics
GRANT SELECT ON information_schema.TABLES TO 'monitoring'@'%';
GRANT SELECT ON information_schema.TABLE_CONSTRAINTS TO 'monitoring'@'%';

-- Grant privileges for replica monitoring
GRANT SELECT ON information_schema.REPLICA_HOST_STATUS TO 'monitoring'@'%';

-- Flush privileges to ensure changes take effect
FLUSH PRIVILEGES;

-- Verify the user was created successfully
SELECT User, Host FROM mysql.user WHERE User = 'monitoring';

-- Show granted privileges for verification
SHOW GRANTS FOR 'monitoring'@'%';
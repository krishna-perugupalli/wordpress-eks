#!/usr/bin/env python3
"""
AWS Cost Monitoring Exporter for Prometheus
Collects cost metrics from AWS Cost Explorer API and exposes them as Prometheus metrics
"""

import os
import time
import yaml
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any

import boto3
from prometheus_client import start_http_server, Gauge, Counter, Info
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Prometheus metrics
aws_cost_daily = Gauge(
    'aws_cost_daily_usd',
    'Daily AWS cost in USD',
    ['service', 'environment', 'project', 'component']
)

aws_cost_monthly = Gauge(
    'aws_cost_monthly_usd',
    'Monthly AWS cost in USD',
    ['service', 'environment', 'project', 'component']
)

aws_cost_forecast = Gauge(
    'aws_cost_forecast_usd',
    'Forecasted AWS cost in USD',
    ['service', 'environment', 'project', 'days_ahead']
)

aws_usage_quantity = Gauge(
    'aws_usage_quantity',
    'AWS service usage quantity',
    ['service', 'unit', 'environment', 'project']
)

aws_optimization_underutilized = Gauge(
    'aws_optimization_underutilized_resources',
    'Number of underutilized resources',
    ['service', 'resource_type', 'environment']
)

aws_optimization_savings_potential = Gauge(
    'aws_optimization_savings_potential_usd',
    'Potential cost savings in USD',
    ['service', 'optimization_type', 'environment']
)

aws_spot_savings = Gauge(
    'aws_spot_savings_usd',
    'Cost savings from spot instances in USD',
    ['environment', 'project']
)

aws_cost_increase_pct = Gauge(
    'aws_cost_increase_percentage',
    'Cost increase percentage',
    ['period', 'service', 'environment']
)

collection_errors = Counter(
    'aws_cost_collection_errors_total',
    'Total number of cost collection errors',
    ['error_type']
)

collection_duration = Gauge(
    'aws_cost_collection_duration_seconds',
    'Duration of cost collection in seconds'
)

exporter_info = Info(
    'aws_cost_exporter',
    'AWS Cost Exporter information'
)


class CostExporter:
    """AWS Cost Monitoring Exporter"""
    
    def __init__(self, config_file: str):
        """Initialize the cost exporter"""
        self.config = self._load_config(config_file)
        self.region = self.config.get('aws_region', 'us-east-1')
        
        # Initialize AWS clients
        self.ce_client = boto3.client('ce', region_name='us-east-1')  # Cost Explorer is us-east-1 only
        self.cloudwatch_client = boto3.client('cloudwatch', region_name=self.region)
        self.ec2_client = boto3.client('ec2', region_name=self.region)
        self.rds_client = boto3.client('rds', region_name=self.region)
        self.elasticache_client = boto3.client('elasticache', region_name=self.region)
        
        # Set exporter info
        exporter_info.info({
            'version': '1.0.0',
            'region': self.region,
            'collection_interval': str(self.config['collection']['interval_seconds'])
        })
        
        logger.info(f"Cost exporter initialized for region {self.region}")
    
    def _load_config(self, config_file: str) -> Dict[str, Any]:
        """Load configuration from YAML file"""
        try:
            with open(config_file, 'r') as f:
                config = yaml.safe_load(f)
            logger.info(f"Configuration loaded from {config_file}")
            return config
        except Exception as e:
            logger.error(f"Failed to load configuration: {e}")
            raise
    
    def collect_cost_and_usage(self):
        """Collect cost and usage data from AWS Cost Explorer"""
        try:
            start_time = time.time()
            
            # Get date ranges
            today = datetime.now().date()
            start_date = (today - timedelta(days=self.config['collection']['lookback_days'])).strftime('%Y-%m-%d')
            end_date = today.strftime('%Y-%m-%d')
            
            # Get cost allocation tags
            tag_keys = self.config.get('cost_allocation_tags', [])
            
            # Query Cost Explorer for daily costs
            logger.info(f"Querying Cost Explorer for period {start_date} to {end_date}")
            
            response = self.ce_client.get_cost_and_usage(
                TimePeriod={
                    'Start': start_date,
                    'End': end_date
                },
                Granularity='DAILY',
                Metrics=['UnblendedCost', 'UsageQuantity'],
                GroupBy=[
                    {'Type': 'DIMENSION', 'Key': 'SERVICE'},
                ]
            )
            
            # Process results
            for result in response.get('ResultsByTime', []):
                date = result['TimePeriod']['Start']
                
                for group in result.get('Groups', []):
                    service = group['Keys'][0]
                    cost = float(group['Metrics']['UnblendedCost']['Amount'])
                    usage = float(group['Metrics']['UsageQuantity']['Amount'])
                    
                    # Extract tags from service name if available
                    environment = self._extract_tag_from_service(service, 'Environment')
                    project = self._extract_tag_from_service(service, 'Project')
                    component = self._extract_tag_from_service(service, 'Component')
                    
                    # Update daily cost metric
                    aws_cost_daily.labels(
                        service=service,
                        environment=environment,
                        project=project,
                        component=component
                    ).set(cost)
                    
                    logger.debug(f"Daily cost for {service}: ${cost:.2f}")
            
            # Query for monthly costs
            month_start = today.replace(day=1).strftime('%Y-%m-%d')
            
            monthly_response = self.ce_client.get_cost_and_usage(
                TimePeriod={
                    'Start': month_start,
                    'End': end_date
                },
                Granularity='MONTHLY',
                Metrics=['UnblendedCost'],
                GroupBy=[
                    {'Type': 'DIMENSION', 'Key': 'SERVICE'},
                ]
            )
            
            for result in monthly_response.get('ResultsByTime', []):
                for group in result.get('Groups', []):
                    service = group['Keys'][0]
                    cost = float(group['Metrics']['UnblendedCost']['Amount'])
                    
                    environment = self._extract_tag_from_service(service, 'Environment')
                    project = self._extract_tag_from_service(service, 'Project')
                    component = self._extract_tag_from_service(service, 'Component')
                    
                    aws_cost_monthly.labels(
                        service=service,
                        environment=environment,
                        project=project,
                        component=component
                    ).set(cost)
                    
                    logger.debug(f"Monthly cost for {service}: ${cost:.2f}")
            
            duration = time.time() - start_time
            collection_duration.set(duration)
            logger.info(f"Cost and usage collection completed in {duration:.2f}s")
            
        except ClientError as e:
            logger.error(f"AWS API error during cost collection: {e}")
            collection_errors.labels(error_type='aws_api_error').inc()
        except Exception as e:
            logger.error(f"Error collecting cost and usage: {e}")
            collection_errors.labels(error_type='general_error').inc()
    
    def collect_cost_forecast(self):
        """Collect cost forecast data"""
        try:
            today = datetime.now().date()
            
            # Forecast for next 7, 14, and 30 days
            for days_ahead in [7, 14, 30]:
                end_date = (today + timedelta(days=days_ahead)).strftime('%Y-%m-%d')
                
                response = self.ce_client.get_cost_forecast(
                    TimePeriod={
                        'Start': today.strftime('%Y-%m-%d'),
                        'End': end_date
                    },
                    Metric='UNBLENDED_COST',
                    Granularity='MONTHLY'
                )
                
                forecast_cost = float(response['Total']['Amount'])
                
                aws_cost_forecast.labels(
                    service='Total',
                    environment='all',
                    project='all',
                    days_ahead=str(days_ahead)
                ).set(forecast_cost)
                
                logger.debug(f"Forecast for {days_ahead} days: ${forecast_cost:.2f}")
                
        except ClientError as e:
            logger.error(f"AWS API error during forecast collection: {e}")
            collection_errors.labels(error_type='forecast_error').inc()
        except Exception as e:
            logger.error(f"Error collecting cost forecast: {e}")
            collection_errors.labels(error_type='general_error').inc()
    
    def analyze_optimization_opportunities(self):
        """Analyze cost optimization opportunities"""
        try:
            optimization_config = self.config.get('optimization', {})
            
            # Check for underutilized EC2 instances
            self._check_underutilized_ec2(optimization_config)
            
            # Check for underutilized RDS instances
            self._check_underutilized_rds(optimization_config)
            
            # Check for underutilized EBS volumes
            self._check_underutilized_ebs(optimization_config)
            
            logger.info("Optimization analysis completed")
            
        except Exception as e:
            logger.error(f"Error analyzing optimization opportunities: {e}")
            collection_errors.labels(error_type='optimization_error').inc()
    
    def _check_underutilized_ec2(self, config: Dict[str, Any]):
        """Check for underutilized EC2 instances"""
        try:
            threshold = config.get('ec2_cpu_threshold', 20)
            
            # Get CloudWatch metrics for EC2 CPU utilization
            end_time = datetime.now()
            start_time = end_time - timedelta(days=7)
            
            instances = self.ec2_client.describe_instances(
                Filters=[{'Name': 'instance-state-name', 'Values': ['running']}]
            )
            
            underutilized_count = 0
            potential_savings = 0.0
            
            for reservation in instances.get('Reservations', []):
                for instance in reservation.get('Instances', []):
                    instance_id = instance['InstanceId']
                    instance_type = instance['InstanceType']
                    
                    # Get average CPU utilization
                    response = self.cloudwatch_client.get_metric_statistics(
                        Namespace='AWS/EC2',
                        MetricName='CPUUtilization',
                        Dimensions=[{'Name': 'InstanceId', 'Value': instance_id}],
                        StartTime=start_time,
                        EndTime=end_time,
                        Period=3600,
                        Statistics=['Average']
                    )
                    
                    if response['Datapoints']:
                        avg_cpu = sum(dp['Average'] for dp in response['Datapoints']) / len(response['Datapoints'])
                        
                        if avg_cpu < threshold:
                            underutilized_count += 1
                            # Estimate savings (simplified)
                            potential_savings += 50.0  # Placeholder value
            
            environment = self._get_environment_from_tags(instances)
            
            aws_optimization_underutilized.labels(
                service='EC2',
                resource_type='instance',
                environment=environment
            ).set(underutilized_count)
            
            aws_optimization_savings_potential.labels(
                service='EC2',
                optimization_type='rightsizing',
                environment=environment
            ).set(potential_savings)
            
            logger.info(f"Found {underutilized_count} underutilized EC2 instances")
            
        except Exception as e:
            logger.error(f"Error checking underutilized EC2: {e}")
    
    def _check_underutilized_rds(self, config: Dict[str, Any]):
        """Check for underutilized RDS instances"""
        try:
            threshold = config.get('rds_connection_threshold', 10)
            
            db_instances = self.rds_client.describe_db_instances()
            
            underutilized_count = 0
            potential_savings = 0.0
            
            for db_instance in db_instances.get('DBInstances', []):
                db_identifier = db_instance['DBInstanceIdentifier']
                
                # Get average database connections
                end_time = datetime.now()
                start_time = end_time - timedelta(days=7)
                
                response = self.cloudwatch_client.get_metric_statistics(
                    Namespace='AWS/RDS',
                    MetricName='DatabaseConnections',
                    Dimensions=[{'Name': 'DBInstanceIdentifier', 'Value': db_identifier}],
                    StartTime=start_time,
                    EndTime=end_time,
                    Period=3600,
                    Statistics=['Average']
                )
                
                if response['Datapoints']:
                    avg_connections = sum(dp['Average'] for dp in response['Datapoints']) / len(response['Datapoints'])
                    
                    if avg_connections < threshold:
                        underutilized_count += 1
                        potential_savings += 100.0  # Placeholder value
            
            aws_optimization_underutilized.labels(
                service='RDS',
                resource_type='db_instance',
                environment='production'
            ).set(underutilized_count)
            
            aws_optimization_savings_potential.labels(
                service='RDS',
                optimization_type='rightsizing',
                environment='production'
            ).set(potential_savings)
            
            logger.info(f"Found {underutilized_count} underutilized RDS instances")
            
        except Exception as e:
            logger.error(f"Error checking underutilized RDS: {e}")
    
    def _check_underutilized_ebs(self, config: Dict[str, Any]):
        """Check for underutilized EBS volumes"""
        try:
            threshold = config.get('ebs_iops_threshold', 100)
            
            volumes = self.ec2_client.describe_volumes(
                Filters=[{'Name': 'status', 'Values': ['in-use']}]
            )
            
            underutilized_count = 0
            potential_savings = 0.0
            
            for volume in volumes.get('Volumes', []):
                volume_id = volume['VolumeId']
                
                # Get average IOPS
                end_time = datetime.now()
                start_time = end_time - timedelta(days=7)
                
                response = self.cloudwatch_client.get_metric_statistics(
                    Namespace='AWS/EBS',
                    MetricName='VolumeReadOps',
                    Dimensions=[{'Name': 'VolumeId', 'Value': volume_id}],
                    StartTime=start_time,
                    EndTime=end_time,
                    Period=3600,
                    Statistics=['Sum']
                )
                
                if response['Datapoints']:
                    total_ops = sum(dp['Sum'] for dp in response['Datapoints'])
                    avg_iops = total_ops / len(response['Datapoints']) / 3600
                    
                    if avg_iops < threshold:
                        underutilized_count += 1
                        potential_savings += 20.0  # Placeholder value
            
            aws_optimization_underutilized.labels(
                service='EBS',
                resource_type='volume',
                environment='production'
            ).set(underutilized_count)
            
            aws_optimization_savings_potential.labels(
                service='EBS',
                optimization_type='volume_type_change',
                environment='production'
            ).set(potential_savings)
            
            logger.info(f"Found {underutilized_count} underutilized EBS volumes")
            
        except Exception as e:
            logger.error(f"Error checking underutilized EBS: {e}")
    
    def track_spot_savings(self):
        """Track Karpenter spot instance savings"""
        try:
            if not self.config.get('karpenter', {}).get('track_spot_savings', False):
                return
            
            # Get spot and on-demand instance costs
            today = datetime.now().date()
            start_date = (today - timedelta(days=7)).strftime('%Y-%m-%d')
            end_date = today.strftime('%Y-%m-%d')
            
            # Query for EC2 costs with purchase option dimension
            response = self.ce_client.get_cost_and_usage(
                TimePeriod={
                    'Start': start_date,
                    'End': end_date
                },
                Granularity='DAILY',
                Metrics=['UnblendedCost'],
                GroupBy=[
                    {'Type': 'DIMENSION', 'Key': 'PURCHASE_OPTION'},
                ],
                Filter={
                    'Dimensions': {
                        'Key': 'SERVICE',
                        'Values': ['Amazon Elastic Compute Cloud - Compute']
                    }
                }
            )
            
            spot_cost = 0.0
            ondemand_cost = 0.0
            
            for result in response.get('ResultsByTime', []):
                for group in result.get('Groups', []):
                    purchase_option = group['Keys'][0]
                    cost = float(group['Metrics']['UnblendedCost']['Amount'])
                    
                    if 'Spot' in purchase_option:
                        spot_cost += cost
                    elif 'On Demand' in purchase_option:
                        ondemand_cost += cost
            
            # Calculate savings (spot instances typically save 60-90%)
            # Estimate what on-demand would have cost
            estimated_ondemand_equivalent = spot_cost / 0.3  # Assuming 70% savings
            savings = estimated_ondemand_equivalent - spot_cost
            
            aws_spot_savings.labels(
                environment='production',
                project='wordpress-eks'
            ).set(savings)
            
            logger.info(f"Spot instance savings: ${savings:.2f}")
            
        except Exception as e:
            logger.error(f"Error tracking spot savings: {e}")
            collection_errors.labels(error_type='spot_tracking_error').inc()
    
    def _extract_tag_from_service(self, service: str, tag_key: str) -> str:
        """Extract tag value from service name (placeholder implementation)"""
        # In a real implementation, this would query resource tags
        return 'unknown'
    
    def _get_environment_from_tags(self, resources: Dict[str, Any]) -> str:
        """Get environment from resource tags"""
        # Placeholder implementation
        return 'production'
    
    def run(self):
        """Main collection loop"""
        interval = self.config['collection']['interval_seconds']
        
        logger.info(f"Starting cost exporter with {interval}s collection interval")
        
        while True:
            try:
                logger.info("Starting cost metrics collection cycle")
                
                self.collect_cost_and_usage()
                self.collect_cost_forecast()
                self.analyze_optimization_opportunities()
                self.track_spot_savings()
                
                logger.info(f"Collection cycle completed. Sleeping for {interval}s")
                time.sleep(interval)
                
            except KeyboardInterrupt:
                logger.info("Received shutdown signal")
                break
            except Exception as e:
                logger.error(f"Error in collection loop: {e}")
                collection_errors.labels(error_type='loop_error').inc()
                time.sleep(60)  # Wait before retrying


def main():
    """Main entry point"""
    config_file = os.getenv('CONFIG_FILE', '/config/config.yaml')
    metrics_port = int(os.getenv('METRICS_PORT', '9090'))
    
    # Start Prometheus metrics server
    start_http_server(metrics_port)
    logger.info(f"Metrics server started on port {metrics_port}")
    
    # Initialize and run exporter
    exporter = CostExporter(config_file)
    exporter.run()


if __name__ == '__main__':
    main()

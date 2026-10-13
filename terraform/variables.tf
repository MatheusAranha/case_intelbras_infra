variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used as a prefix for every resource and in tags."
  type        = string
  default     = "iot-events"
}

variable "environment" {
  description = "Environment name (e.g. baseline, staging, production)."
  type        = string
  default     = "baseline"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to spread subnets, MSK brokers, and ECS tasks across. MSK requires at least 2."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# --- MSK (Kafka) ---

variable "msk_broker_instance_type" {
  description = "MSK broker instance type. kafka.t3.small is the cheapest provisioned option, suitable for the baseline tier."
  type        = string
  default     = "kafka.t3.small"
}

variable "msk_broker_count" {
  description = "Number of MSK brokers. Matches the backend's recommended replication factor of 3 (see case_intelbras_kafka_java/ARCHITECTURE.md)."
  type        = number
  default     = 3
}

variable "msk_broker_storage_gb" {
  description = "EBS storage per broker, in GB."
  type        = number
  default     = 100
}

variable "msk_kafka_version" {
  description = "Kafka version for the MSK cluster."
  type        = string
  default     = "3.8.x"
}

# --- ECS / Fargate (the Spring Boot app) ---

variable "app_image" {
  description = "Full ECR image URI (with tag) for the iot-events app container. Placeholder until a real image is pushed."
  type        = string
  default     = "REPLACE_ME.dkr.ecr.us-east-1.amazonaws.com/iot-events:latest"
}

variable "ecs_task_cpu" {
  description = "Fargate task vCPU units (1024 = 1 vCPU)."
  type        = number
  default     = 1024
}

variable "ecs_task_memory" {
  description = "Fargate task memory, in MB."
  type        = number
  default     = 2048
}

variable "ecs_desired_count" {
  description = "Baseline number of running app tasks."
  type        = number
  default     = 2
}

# --- RDS (Postgres, the audit store) ---

variable "rds_instance_class" {
  description = "RDS instance class for the audit_records database."
  type        = string
  default     = "db.t3.medium"
}

variable "rds_allocated_storage_gb" {
  description = "RDS storage, in GB (gp3)."
  type        = number
  default     = 50
}

variable "rds_multi_az" {
  description = "Whether RDS runs Multi-AZ. false in the cost-conscious baseline; true is the first scaling step for availability."
  type        = bool
  default     = false
}

variable "rds_database_name" {
  description = "Database name, matching application.yml's DB_NAME."
  type        = string
  default     = "iotevents"
}

# --- Observability ---

variable "alert_notification_email" {
  description = "Email address subscribed to the SNS topic that receives alert notifications (the AWS equivalent of observability/alerts.yml)."
  type        = string
  default     = "ops@example.com"
}

variable "grafana_admin_user_arns" {
  description = "IAM user/role ARNs granted Admin access to the Amazon Managed Grafana workspace."
  type        = list(string)
  default     = []
}

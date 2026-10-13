# Amazon Managed Prometheus — remote-write target for the ADOT sidecar that
# scrapes each task's /actuator/prometheus, same metrics the local stack's
# Prometheus already scrapes (see case_intelbras_kafka_java/observability/).
resource "aws_prometheus_workspace" "main" {
  alias = "${var.project_name}-amp"
}

# Portable version of observability/alerts.yml's 5 rules — same expressions,
# same metric names, running against AMP instead of local Prometheus.
resource "aws_prometheus_rule_group_namespace" "alerts" {
  name         = "${var.project_name}-alerts"
  workspace_id = aws_prometheus_workspace.main.id

  data = yamlencode({
    groups = [{
      name = "iot-events-app"
      rules = [
        {
          alert  = "DeviceEventsDeadLettered"
          expr   = "increase(device_events_dlq_total[5m]) > 0"
          for    = "0m"
          labels = { severity = "warning" }
          annotations = {
            summary = "Device events are being dead-lettered"
          }
        },
        {
          alert  = "AuditConsumerLagHigh"
          expr   = "sum(kafka_consumer_fetch_manager_records_lag) by (topic) > 100"
          for    = "5m"
          labels = { severity = "warning" }
          annotations = {
            summary = "Kafka consumer lag is high on {{ $labels.topic }}"
          }
        },
        {
          alert  = "RandomStreamPublishGap"
          expr   = "(increase(random_stream_requested_total[5m]) - increase(random_stream_published_total[5m])) / clamp_min(increase(random_stream_requested_total[5m]), 1) > 0.05"
          for    = "2m"
          labels = { severity = "warning" }
          annotations = {
            summary = "Random event stream requests are outpacing successful publishes"
          }
        },
        {
          alert  = "IotEventsAppDown"
          expr   = "up{job=\"iot-events-app\"} == 0"
          for    = "1m"
          labels = { severity = "critical" }
          annotations = {
            summary = "iot-events-app is unreachable"
          }
        },
        {
          alert  = "DuplicateRateHigh"
          expr   = "(rate(device_events_duplicate_total[5m]) / clamp_min(rate(device_events_processed_total[5m]), 1e-9)) > 0.5"
          for    = "5m"
          labels = { severity = "warning" }
          annotations = {
            summary = "Abnormally high duplicate event rate"
          }
        },
      ]
    }]
  })
}

resource "aws_prometheus_alert_manager_definition" "main" {
  workspace_id = aws_prometheus_workspace.main.id

  definition = yamlencode({
    route = {
      receiver = "sns"
    }
    receivers = [{
      name = "sns"
      sns_configs = [{
        topic_arn = aws_sns_topic.alerts.arn
        sigv4 = {
          region = var.aws_region
        }
      }]
    }]
  })
}

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_notification_email
}

resource "aws_grafana_workspace" "main" {
  name                     = "${var.project_name}-grafana"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
  role_arn                 = aws_iam_role.grafana.arn

  data_sources = ["PROMETHEUS"]
}

resource "aws_iam_role" "grafana" {
  name = "${var.project_name}-grafana"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "grafana.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "grafana_amp" {
  role       = aws_iam_role.grafana.name
  policy_arn = "arn:aws:iam::aws:policy/AWSGrafanaWorkspacePermissionManagementV2"
}

resource "aws_grafana_role_association" "admins" {
  count        = length(var.grafana_admin_user_arns) > 0 ? 1 : 0
  role         = "ADMIN"
  user_ids     = var.grafana_admin_user_arns
  workspace_id = aws_grafana_workspace.main.id
}

# ECS task logs (the structured ExecutionLog JSON lines, unchanged from the app).
resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project_name}/app"
  retention_in_days = 30
}

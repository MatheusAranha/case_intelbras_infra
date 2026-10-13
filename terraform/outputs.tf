output "app_url" {
  description = "Public URL for the REST API."
  value       = "http://${aws_lb.app.dns_name}"
}

output "ecr_repository_url" {
  description = "Push the app image here before deploying."
  value       = aws_ecr_repository.app.repository_url
}

output "msk_bootstrap_brokers_iam" {
  description = "Kafka bootstrap servers, IAM-auth endpoint."
  value       = aws_msk_cluster.main.bootstrap_brokers_sasl_iam
}

output "rds_endpoint" {
  description = "Postgres connection endpoint."
  value       = aws_db_instance.audit_store.address
}

output "grafana_workspace_url" {
  description = "Amazon Managed Grafana workspace URL."
  value       = aws_grafana_workspace.main.endpoint
}

output "prometheus_workspace_id" {
  description = "Amazon Managed Prometheus workspace ID (for console/alerts)."
  value       = aws_prometheus_workspace.main.id
}

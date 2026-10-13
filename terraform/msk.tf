# Amazon MSK — managed Kafka. Mirrors the project's existing 4-topic /
# 3-partition-per-topic design (config/KafkaTopics.java); Terraform owns only
# the cluster, not the topics — the app keeps creating topics itself via its
# existing @Bean NewTopic definitions (KafkaTopicConfig.java), so there is a
# single source of truth for topic configuration, same as it is locally.

resource "aws_cloudwatch_log_group" "msk_broker_logs" {
  name              = "/${var.project_name}/msk/broker-logs"
  retention_in_days = 14
}

resource "aws_msk_configuration" "main" {
  name              = "${var.project_name}-config"
  kafka_versions    = [var.msk_kafka_version]
  server_properties = <<-PROPERTIES
    auto.create.topics.enable=false
    default.replication.factor=3
    min.insync.replicas=2
    num.partitions=3
  PROPERTIES
}

resource "aws_msk_cluster" "main" {
  cluster_name           = "${var.project_name}-kafka"
  kafka_version          = var.msk_kafka_version
  number_of_broker_nodes = var.msk_broker_count

  broker_node_group_info {
    instance_type   = var.msk_broker_instance_type
    client_subnets  = aws_subnet.private[*].id
    security_groups = [aws_security_group.msk.id]

    storage_info {
      ebs_storage_info {
        volume_size = var.msk_broker_storage_gb
      }
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.main.arn
    revision = aws_msk_configuration.main.latest_revision
  }

  client_authentication {
    sasl {
      iam = true
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk_broker_logs.name
      }
    }
  }

  tags = { Name = "${var.project_name}-kafka" }
}

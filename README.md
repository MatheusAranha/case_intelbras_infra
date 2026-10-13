# case_intelbras_infra

An AWS infrastructure-as-code **proposal** for the backend in
[case_intelbras_kafka_java](../case_intelbras_kafka_java) — the Intelbras Backend
Sênior case. Frontend ([case_intelbras_frontend](../case_intelbras_frontend)) is out of
scope.

**This has never been applied.** It's real, `terraform validate`-clean Terraform
describing a concrete proposal, meant to be reviewed before any AWS resource exists —
not a running deployment.

Start with **[PROPOSAL.md](PROPOSAL.md)**: what's being proposed and why, the Mermaid
architecture diagram, a monthly cost breakdown, an estimated message-throughput capacity
at that cost (per minute/day/month), and a scaling plan with cost/capacity deltas for
each lever.

## Reviewing this without an AWS account

```bash
cd terraform
terraform init -backend=false   # downloads providers only, no AWS calls
terraform validate              # confirms the config is syntactically/internally sound
terraform fmt -check            # confirms formatting
```

`terraform plan` or `apply` would need real AWS credentials and a filled-in
`terraform.tfvars` (copy `terraform.tfvars.example`) — neither is needed to review the
proposal itself.

## Layout

```
PROPOSAL.md           — the actual proposal: architecture, costs, capacity, scaling
terraform/
  versions.tf          — providers, backend note (local state; a real deployment uses S3+DynamoDB)
  variables.tf          — every sizing knob, with the baseline tier as the default
  vpc.tf                — VPC, subnets, 1 NAT Gateway, route tables
  security_groups.tf   — least-privilege SGs (ALB → app → MSK/RDS)
  msk.tf                — Amazon MSK cluster (Terraform owns the cluster, the app owns topics)
  ecs.tf                — ECS cluster/service/task def, ALB, autoscaling policy
  rds.tf                — RDS PostgreSQL (the audit store)
  ecr.tf                — container registry for the app image
  secrets.tf            — RDS credentials in Secrets Manager
  iam.tf                — task execution role, task role (Kafka IAM auth, AMP remote-write)
  observability.tf      — Amazon Managed Prometheus + alert rules + Grafana + SNS + CloudWatch Logs
  outputs.tf
  terraform.tfvars.example
```

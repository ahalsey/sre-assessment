# Platform SRE Assessment

## Overview

This repository provisions a production-ready AWS EKS platform using Terraform, following Infrastructure-as-Code best practices. The infrastructure is fully automated through GitHub Actions, modular in design, and built with security and observability as first-class concerns.

## LLM Usage:

Claude Opus 4.6 was used for drafting the below architecture diagram, generating `bootstrap-backend.sh`, the GitHub Workflow, and general connectivity troubleshooting.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  AWS Account                                                     │
│                                                                  │
│  ┌────────────────── VPC (10.0.0.0/16) ───────────────────────┐  │
│  │                                                            │  │
│  │   Public Subnets (AZ-a, AZ-b)                              │  │
│  │   ┌──────────────┐  ┌──────────────┐                       │  │
│  │   │  NAT Gateway │  │  (reserved   │                       │  │
│  │   │              │  │   for ALB)   │                       │  │
│  │   └──────┬───────┘  └──────────────┘                       │  │
│  │          │                                                 │  │
│  │   Private Subnets (AZ-a, AZ-b)                             │  │
│  │   ┌──────────────────────────────────────────────┐         │  │
│  │   │           EKS Cluster (v1.35)                │         │  │
│  │   │                                              │         │  │
│  │   │  ┌─────────┐  ┌─────────┐  ┌─────────────┐   │         │  │
│  │   │  │ adminer │  │ adminer │  │LB Controller│   │         │  │
│  │   │  │  pod    │  │  pod    │  │(kube-system)│   │         │  │
│  │   │  └─────────┘  └─────────┘  └─────────────┘   │         │  │
│  │   │                                              │         │  │
│  │   │  Managed Node Group (t3.medium × 2)          │         │  │
│  │   │  AL2023 AMI                                  │         │  │
│  │   └──────────────────────────────────────────────┘         │  │
│  │          │                                                 │  │
│  │   Database Subnets (AZ-a, AZ-b) — isolated                 │  │
│  │   ┌──────────────────────────────┐                         │  │
│  │   │  RDS PostgreSQL 16           │                         │  │
│  │   │  db.t3.micro | gp3 | 20 GiB  │                         │  │
│  │   │  Encrypted (KMS) | TLS       │                         │  │
│  │   └──────────────────────────────┘                         │  │
│  │                                                            │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌─ Observability ──────────┐  ┌─ State Management ───────────┐  │
│  │ CloudWatch Logs          │  │ S3 (versioned, KMS)          │  │
│  │ VPC Flow Logs (REJECT)   │  │ DynamoDB (state locking)     │  │
│  │ RDS Performance Insights │  │                              │  │
│  │ SNS Alerts (encrypted)   │  └──────────────────────────────┘  │
│  │ CPU/Memory/Storage Alarms│                                    │
│  └──────────────────────────┘                                    │
└──────────────────────────────────────────────────────────────────┘

┌─ CI/CD (GitHub Actions) ─────────────────────────────────────────┐
│                                                                  │
│  PR → tf fmt + tfsec + validate + plan (comment on PR)           │
│  Merge → terraform apply (OIDC auth, no long-lived keys)         │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Module Structure

The Terraform codebase is split into five reusable modules, each with its own `variables.tf`, `outputs.tf`, and `main.tf`:

| Module | Responsibility | Key Outputs |
|--------|---------------|-------------|
| **vpc** | VPC, 3-tier subnets (public/private/database), NAT, IGW, flow logs, route tables | `vpc_id`, `private_subnet_ids`, `database_subnet_ids` |
| **eks** | EKS cluster, managed node group, OIDC/IRSA, KMS secrets encryption, addons, LB controller | `cluster_name`, `cluster_endpoint`, `node_security_group_id` |
| **rds** | PostgreSQL 16, KMS encryption, TLS enforcement, Secrets Manager, enhanced monitoring | `endpoint`, `port`, `secret_arn` |
| **app** | K8s namespace, Deployment, Service, ConfigMap, health checks | `service_url`, `namespace` |
| **observability** | CloudWatch log groups, SNS topic (KMS-encrypted), metric alarms | `sns_topic_arn`, `log_group_name` |

Each module is parameterized so it can be reused across environments with different sizing. The root module composes them together, and environment-specific configs under `env/dev/` provide the variable values.

---

## Security Posture

### Network Hardening

- **3-tier subnet architecture**: Public subnets for NAT/load balancers, private subnets for EKS nodes, isolated database subnets with no internet route
- **EKS nodes in private subnets**: No direct internet exposure; outbound via NAT gateway
- **RDS not publicly accessible**: Security group allows ingress only from EKS node security group on port 5432
- **VPC Flow Logs**: Captures rejected traffic for security auditing, shipped to CloudWatch with 30-day retention

### Least-Privilege IAM

- **OIDC federation for CI/CD**: No long-lived AWS access keys; GitHub Actions assumes a role via short-lived tokens scoped to the specific repository
- **IRSA for LB Controller**: The AWS Load Balancer Controller uses a dedicated IAM role bound to its specific Kubernetes service account via OIDC
- **Separate IAM roles**: Cluster role, node role, RDS monitoring role, VPC flow logs role — each with only the permissions they need
- **EKS access entries**: Explicit API-based access control (`API_AND_CONFIG_MAP` mode) instead of implicit cluster-creator admin

### Encryption

- **EKS secrets**: Encrypted at rest with a dedicated KMS key (key rotation enabled)
- **RDS storage**: Encrypted with a dedicated KMS key (key rotation enabled)
- **RDS in transit**: `rds.force_ssl = 1` enforced via parameter group
- **RDS Performance Insights**: Encrypted with the same KMS key
- **SNS topic**: Encrypted with a dedicated KMS key
- **Terraform state**: S3 bucket with KMS encryption and versioning
- **Secrets Manager**: DB credentials auto-generated (32-char, no shell-special characters) and stored securely

---

## Observability

### Logging

- **EKS control plane logs**: API server, audit, authenticator, controller manager, scheduler — all enabled
- **VPC Flow Logs**: Rejected traffic captured for network security analysis
- **RDS Enhanced Monitoring**: 60-second granularity OS-level metrics

### Metrics & Alerting

CloudWatch alarms with SNS notifications for:

- EKS node CPU utilization > 80% (15 min sustained)
- EKS node memory utilization > 80% (15 min sustained)
- RDS CPU utilization > 80% (15 min sustained)
- RDS free storage < 2 GiB

### Health Checks

- Kubernetes liveness probe: HTTP GET on `/` every 10s (3 failure threshold)
- Kubernetes readiness probe: HTTP GET on `/` every 5s
- RDS Performance Insights: enabled with KMS encryption

---

## GitOps & CI/CD

### Pipeline Flow

```
Developer → feature branch → Pull Request
                                  │
                          ┌───────▼────────┐
                          │  tf-plan.yml   │
                          │                │
                          │ 1. fmt check   │
                          │ 2. tfsec scan  │
                          │ 3. validate    │
                          │ 4. plan        │
                          │ 5. PR comment  │
                          └───────┬────────┘
                                  │
                          Review & Approve
                                  │
                          ┌───────▼────────┐
                          │  tf-apply.yml  │
                          │                │
                          │ 1. init        │
                          │ 2. plan        │
                          │ 3. apply       │
                          └────────────────┘
```

### Key Design Decisions

- **OIDC authentication**: No static AWS credentials stored anywhere; GitHub's identity provider is trusted by AWS IAM
- **tfsec security scanning**: Runs on every PR to catch misconfigurations before they reach infrastructure
- **Plan-on-PR / Apply-on-merge**: Changes are reviewed with full Terraform plan output before any infrastructure is modified
- **Remote state with locking**: S3 backend with DynamoDB prevents concurrent modifications and state corruption
- **Environment change detection**: CI only plans/applies environments that have changed files, reducing unnecessary runs

---

## Cost Optimization

This demo is sized for minimal cost:

- **Single NAT gateway** instead of one per AZ
- **t3.medium nodes** (2 vCPU, 4 GiB) — smallest practical for EKS
- **db.t3.micro RDS** — burstable, single-AZ
- **gp3 storage** — cheaper than gp2 with better baseline performance
- **ON_DEMAND capacity** — SPOT noted as option for further savings
- **20 GiB node disks** — minimal footprint

---

## Demo Application

The demo deploys an **adminer** container as a Kubernetes Deployment with:

- 2 replicas
- Resource requests/limits (50m–200m CPU, 64Mi–128Mi memory)
- Liveness and readiness probes
- Prometheus scrape annotations
- Database connection details injected via ConfigMap
- LoadBalancer service

### Verifying the Application

```bash
# Check pods are running
kubectl get pods -n demo

# Check service
kubectl get svc -n demo

# Access the application
kubectl port-forward -n demo svc/platform-sre-demo 8080:80
# Open http://localhost:8080
```

---

## TODO Wishlist

To adhere to "quality and clarity of thought rather than breadth of features", none of the following were included. For a cluster handling production workloads, I would add:

1. **Ingress with TLS**: AWS Load Balancer Controller with ACM certificate for HTTPS termination
2. **Prometheus + Grafana**: Full metrics stack via Helm, replacing CloudWatch-only monitoring
3. **Pod Disruption Budgets**: Ensure availability during node drains and upgrades
4. **Network Policies**: Restrict pod-to-pod communication at the CNI level
5. **Terraform module registry**: Publish modules for cross-team reuse
6. **Cost monitoring**: AWS Cost Explorer integration with budget alerts
7. **Disaster recovery**: Automated RDS snapshots with cross-region replication

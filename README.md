# 🚗 CarsHub — VM-Based REST API Infrastructure on AWS

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-623CE4?style=for-the-badge&logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Multi--Service-FF9900?style=for-the-badge&logo=amazon-aws)](https://aws.amazon.com/)
[![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?style=for-the-badge&logo=mysql&logoColor=white)](https://www.mysql.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)

A production-grade, fully automated AWS infrastructure for the CarsHub application — a vehicle listing and media management platform. Built entirely with Terraform, this project provisions a highly available, auto-scaling VM-based architecture with multi-layer security, event-driven media processing, and comprehensive observability.

---

## 📋 Table of Contents

- [Architecture Overview](#-architecture-overview)
- [Key Features](#-key-features)
- [Infrastructure Components](#-infrastructure-components)
- [Security Design](#-security-design)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Configuration](#-configuration)
- [Monitoring & Alerting](#-monitoring--alerting)
- [Cost Estimate](#-cost-estimate)
- [Project Structure](#-project-structure)
- [Troubleshooting](#-troubleshooting)

---

## 🏗️ Architecture Overview

```
                          ┌─────────────────────────────────────────────────────┐
                          │                   AWS Cloud (VPC)                    │
                          │                  CIDR: 10.0.0.0/16                  │
                          │                                                       │
   Users ──────────────► ALB (Frontend)          ALB (Backend)                  │
                          │   Port 80               Port 80                      │
                          │     │                      │                         │
                          │  ┌──▼───────────────────────▼──┐                    │
                          │  │        Private Subnets        │                   │
                          │  │                               │                   │
                          │  │  ┌──────────────┐  ┌───────────────────┐        │
                          │  │  │ Frontend ASG │  │   Backend ASG     │        │
                          │  │  │ (Next.js)    │  │   (NestJS/Node)   │        │
                          │  │  │ min:3 max:50 │  │   min:3 max:50    │        │
                          │  │  │  port: 3000  │  │     port: 80      │        │
                          │  │  └──────────────┘  └────────┬──────────┘        │
                          │  │                             │                    │
                          │  │  ┌──────────────────────────▼──────────────┐    │
                          │  │  │         Database Subnets                 │    │
                          │  │  │   RDS MySQL 8.0 (Multi-AZ)              │    │
                          │  │  │   db.r6g.large │ 100GB GP3              │    │
                          │  │  └─────────────────────────────────────────┘    │
                          │  └───────────────────────────────────────────────── ┘
                          │                                                       │
                          │  ┌──────────────────────────────────────────────┐   │
                          │  │              Event-Driven Media Pipeline      │   │
                          │  │                                               │   │
                          │  │  S3 Upload → SQS Queue → Lambda → RDS        │   │
                          │  │      └──► CloudFront CDN (OAC)               │   │
                          │  └──────────────────────────────────────────────┘   │
                          └─────────────────────────────────────────────────────┘
```

### Data Flow

```
1. User Request:   Browser → Frontend ALB → Frontend ASG (Next.js) → Backend ALB → Backend ASG (NestJS)
2. Media Upload:   Backend → S3 Bucket → SQS Event → Lambda → RDS (metadata update)
3. Media Fetch:    Browser → CloudFront CDN (OAC) → S3 (private, no public access)
4. DB Auth:        EC2 Instances → Secrets Manager → RDS MySQL (IAM auth enabled)
```

---

## ✨ Key Features

### 🔒 Security
- **Zero hardcoded credentials** — HashiCorp Vault as source of truth, AWS Secrets Manager for runtime
- **Private subnets** for all compute (ASG instances, RDS, Lambda)
- **Layered security groups** — frontend LB → backend LB → ASG → RDS, each explicitly scoped
- **CloudFront OAC** — S3 bucket has no public access; served exclusively via CloudFront with Origin Access Control
- **Lambda code signing** — All Lambda deployments validated via AWS Signer (ECDSA-SHA384)
- **VPC Flow Logs** — Full network traffic capture to CloudWatch (365-day retention)
- **IAM database authentication** enabled on RDS
- **RDS encryption at rest** with storage_encrypted = true

### 📈 High Availability & Scalability
- **Multi-AZ RDS** with automated failover
- **Auto Scaling Groups** for both frontend and backend (min: 3, max: 50 per tier)
- **ELB health checks** integrated with ASG for automatic instance replacement
- **Multi-AZ NAT Gateways** — one per AZ, no single point of failure for outbound traffic
- **SQS buffering** between S3 events and Lambda — decouples media processing from uploads

### 🔍 Observability
- **7 CloudWatch Alarms** covering: ALB response time (p95), 5XX errors, Lambda errors, SQS depth, RDS CPU, RDS storage, RDS connections
- **RDS Enhanced Monitoring** (60-second granularity)
- **RDS Performance Insights** (7-day retention)
- **RDS slow query logging** enabled
- **ALB access logs** to dedicated S3 buckets (frontend + backend)
- **SNS email notifications** for all alarm state changes
- **AWS Resource Groups** for unified project-level visibility

### 🎬 Event-Driven Media Processing
- S3 object creation triggers SQS message (decoupled, no direct Lambda trigger)
- SQS → Lambda with dead-letter queue for failed processing
- Lambda updates RDS metadata with media file information
- Lambda deployed in VPC with scoped egress (RDS port 3306 + HTTPS to S3 only)

---

## 🧩 Infrastructure Components

| Component | Service | Configuration | Purpose |
|---|---|---|---|
| **Frontend ALB** | Application Load Balancer | Public, port 80 | Terminates user traffic, routes to frontend ASG |
| **Backend ALB** | Application Load Balancer | Public, port 80 | Internal-facing, routes to backend ASG |
| **Frontend ASG** | EC2 Auto Scaling | t2.micro, min 3 / max 50 | Runs Next.js frontend |
| **Backend ASG** | EC2 Auto Scaling | t2.micro, min 3 / max 50 | Runs NestJS REST API |
| **RDS MySQL** | RDS | db.r6g.large, Multi-AZ, 100–500GB GP3 | Primary application database |
| **S3 Media Bucket** | S3 | Versioned, private, CloudFront OAC | Stores vehicle images and documents |
| **CloudFront CDN** | CloudFront | OAC, HTTPS redirect, 1yr TTL | Serves media securely and efficiently |
| **Lambda** | Lambda | Python 3.12, VPC-attached, signed | Updates RDS media metadata on S3 upload |
| **SQS Queue** | SQS | DLQ enabled, 60s batch window | Buffers S3 events for Lambda |
| **Secrets Manager** | Secrets Manager | Vault-sourced | Stores RDS credentials for Lambda runtime |
| **VPC Flow Logs** | CloudWatch Logs | ALL traffic, 365-day retention | Network audit and security monitoring |
| **SNS** | SNS | Email subscription | Alarm notifications |

---

## 🔒 Security Design

### Network Segmentation

```
Internet
    │
    ▼
[Frontend ALB SG]  ← allows 0.0.0.0/0 on 80/443
    │
    ▼
[Frontend ASG SG]  ← allows only Frontend ALB SG on port 3000
    │
    ▼
[Backend ALB SG]   ← allows only Frontend LB SG on 80/443
    │
    ▼
[Backend ASG SG]   ← allows only Backend ALB SG on port 80
    │
    ▼
[RDS SG]           ← allows only Backend ASG SG on port 3306
    │
[Lambda SG]        ← egress only: port 3306 → RDS SG, port 443 → 0.0.0.0/0 (S3)
```

### Credential Flow

```
HashiCorp Vault  ──read──►  Terraform (plan/apply time)
                                    │
                     ┌──────────────┴──────────────┐
                     ▼                             ▼
            AWS Secrets Manager           EC2 user_data (env vars)
                     │                        [RDS direct connection]
                     ▼
            Lambda function (runtime)
            [reads secret by name, no hardcoding]
```

### Lambda Code Signing Pipeline

```
Source Code → S3 (unsigned bucket) → AWS Signer (ECDSA SHA-384) → S3 (signed bucket) → Lambda deploy
```

All Lambda deployments are blocked unless the artifact is signed by the registered signing profile.

---

## 📦 Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| [Terraform](https://www.terraform.io/downloads) | ≥ 1.0 | Infrastructure provisioning |
| [AWS CLI](https://aws.amazon.com/cli/) | ≥ 2.0 | AWS authentication |
| [Vault CLI](https://www.vaultproject.io/downloads) | ≥ 1.8 | Secret retrieval at plan time |

### Required Vault Secrets

```bash
# RDS credentials
vault kv put secret/rds \
  username="your_db_username" \
  password="your_secure_password"
```

### Required AWS Permissions

The Terraform execution role needs permissions for: EC2, RDS, S3, Lambda, SQS, CloudFront, CloudWatch, Secrets Manager, IAM, SNS, VPC.

---

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/mmdcloud/aws-carshub-rest-vm.git
cd aws-carshub-rest-vm/terraform
```

### 2. Configure Vault

```bash
export VAULT_ADDR=https://your-vault-instance.com
export VAULT_TOKEN=your-vault-token

vault kv put secret/rds username=admin password=SecurePass123!
```

### 3. Prepare Lambda Artifact

```bash
# Build and place Lambda deployment package
cd src/lambda
pip install -r requirements.txt -t .
zip -r ../../../files/lambda.zip .
zip -r ../../../files/python.zip dependencies/
```

### 4. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
env    = "prod"
region = "us-east-1"
project = "carshub"

azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnets = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
database_subnets = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]

db_name = "carshubdbproduseast1"
```

### 5. Deploy

```bash
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

### 6. Verify Deployment

```bash
# Check ALB DNS names
terraform output frontend_lb_dns
terraform output backend_lb_dns

# Verify RDS is available
aws rds describe-db-instances \
  --db-instance-identifier carshub-db-prod \
  --query 'DBInstances[0].DBInstanceStatus'

# Confirm ASG instances are healthy
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names carshub_frontend_asg_prod \
  --query 'AutoScalingGroups[0].Instances[*].HealthStatus'
```

---

## ⚙️ Configuration

### Variable Reference

| Variable | Description | Example |
|---|---|---|
| `env` | Deployment environment | `prod`, `staging` |
| `region` | AWS region | `us-east-1` |
| `project` | Project tag value | `carshub` |
| `azs` | Availability zones | `["us-east-1a", "us-east-1b", "us-east-1c"]` |
| `public_subnets` | CIDR blocks for public subnets | `["10.0.1.0/24", ...]` |
| `private_subnets` | CIDR blocks for private subnets | `["10.0.11.0/24", ...]` |
| `database_subnets` | CIDR blocks for DB subnets | `["10.0.21.0/24", ...]` |
| `db_name` | RDS database name | `carshubdbproduseast1` |

### RDS Parameter Tuning

Key parameters configured in the parameter group:

| Parameter | Value | Reason |
|---|---|---|
| `max_connections` | 1000 | Supports high ASG concurrency |
| `slow_query_log` | 1 | Captures queries for performance analysis |

Additional parameters (commented, ready to enable):
- `innodb_buffer_pool_size`, `long_query_time`, `max_allowed_packet`, `character_set_server`, `innodb_flush_log_at_trx_commit`

---

## 📊 Monitoring & Alerting

### CloudWatch Alarms

| Alarm | Metric | Threshold | Action |
|---|---|---|---|
| Frontend ALB response time | `TargetResponseTime` p95 | > 1s | SNS email |
| Frontend ALB 5XX errors | `HTTPCode_Target_5XX_Count` | > 10/min | SNS email |
| Backend ALB response time | `TargetResponseTime` p95 | > 1s | SNS email |
| Backend ALB 5XX errors | `HTTPCode_Target_5XX_Count` | > 10/min | SNS email |
| Lambda errors | `Errors` | > 0 per 5 min | SNS email |
| SQS queue depth | `ApproximateNumberOfMessagesVisible` | > 100 | SNS email |
| RDS CPU | `CPUUtilization` | > 80% for 10 min | SNS email |
| RDS free storage | `FreeStorageSpace` | < 10 GB | SNS email |
| RDS connections | `DatabaseConnections` | > 100 | SNS email |

### Log Locations

| Component | Log Destination |
|---|---|
| Frontend ALB access logs | `s3://carshub-frontend-lb-logs-{env}-{region}/` |
| Backend ALB access logs | `s3://carshub-backend-lb-logs-{env}-{region}/` |
| VPC Flow Logs | CloudWatch: `/aws/vpc/flow-logs/carshub-application-{env}-{region}` |
| RDS logs | CloudWatch: audit, error, general, slowquery |
| Lambda logs | CloudWatch: `/aws/lambda/carshub-media-update-{env}-{region}` |

### Accessing Logs

```bash
# Tail Lambda logs
aws logs tail /aws/lambda/carshub-media-update-prod-us-east-1 --follow

# Query RDS slow query log
aws rds download-db-log-file-portion \
  --db-instance-identifier carshub-db-prod \
  --log-file-name slowquery/mysql-slowquery.log \
  --output text

# Check SQS DLQ for failed media events
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/ACCOUNT/carshub-media-events-dlq-prod-us-east-1 \
  --attribute-names ApproximateNumberOfMessages
```

---

## 💰 Cost Estimate (us-east-1, prod)

| Service | Configuration | Est. Monthly Cost |
|---|---|---|
| RDS MySQL | db.r6g.large Multi-AZ, 100GB GP3 | ~$380 |
| EC2 Frontend ASG | 3x t2.micro (min) | ~$25 |
| EC2 Backend ASG | 3x t2.micro (min) | ~$25 |
| NAT Gateways | 3x (one per AZ) | ~$100 |
| ALB x2 | Frontend + Backend | ~$35 |
| CloudFront | PriceClass_100 | ~$10–30 |
| S3 | Media + logs + code | ~$15 |
| Lambda | Event-driven, minimal | ~$1 |
| SQS | Low volume | ~$1 |
| CloudWatch | Logs + alarms + metrics | ~$20 |
| **Total (minimum)** | | **~$612/month** |

> Costs scale with ASG instance count and media storage volume. Use AWS Cost Anomaly Detection and Budgets to monitor spend.

---

## 📁 Project Structure

```
.
├── terraform/
│   ├── main.tf                          # All infrastructure resources
│   ├── variables.tf                     # Input variable definitions
│   ├── outputs.tf                       # Output values
│   ├── terraform.tfvars.example         # Example variable file (gitignored actual)
│   └── modules/
│       ├── vpc/                         # VPC, subnets, IGW, NAT, route tables
│       ├── security-groups/             # Reusable SG module
│       ├── rds/                         # RDS instance + parameter group + subnet group
│       ├── s3/                          # S3 bucket with policy, CORS, versioning, notifications
│       ├── sqs/                         # SQS queue with DLQ support
│       ├── lambda/                      # Lambda function with VPC + signing config
│       ├── signing-profile/             # AWS Signer profile + signing job
│       ├── cloudfront/                  # CloudFront distribution with OAC
│       ├── iam/                         # Reusable IAM role + policy module
│       ├── launch_template/             # EC2 launch template
│       ├── auto_scaling_group/          # ASG with ELB health checks
│       ├── secrets-manager/             # Secrets Manager secret
│       ├── sns/                         # SNS topic + subscriptions
│       └── cloudwatch/
│           ├── cloudwatch-alarm/        # Reusable CloudWatch alarm module
│           └── cloudwatch-log-group/    # Log group with retention
├── scripts/
│   ├── user_data_frontend.sh            # Frontend EC2 bootstrap (Next.js)
│   └── user_data_backend.sh             # Backend EC2 bootstrap (NestJS)
├── files/
│   ├── lambda.zip                       # Lambda deployment package (gitignored)
│   └── python.zip                       # Lambda layer with dependencies (gitignored)
└── README.md
```

---

## 🔧 Troubleshooting

### ASG Instances Failing Health Checks

```bash
# Check instance system logs
aws ec2 get-console-output --instance-id i-xxxx

# Verify user_data executed correctly
# SSH to instance and check:
cat /var/log/cloud-init-output.log

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:...
```

### Lambda Not Processing S3 Events

```bash
# Check SQS queue depth
aws sqs get-queue-attributes \
  --queue-url <queue-url> \
  --attribute-names ApproximateNumberOfMessages

# Check DLQ for failed messages
aws sqs receive-message \
  --queue-url <dlq-url> \
  --max-number-of-messages 10

# Check Lambda CloudWatch logs
aws logs tail /aws/lambda/carshub-media-update-prod-us-east-1 --follow
```

### RDS Connection Refused

```bash
# Verify security group allows backend ASG SG on 3306
aws ec2 describe-security-groups --group-ids <rds-sg-id>

# Check RDS instance status
aws rds describe-db-instances \
  --db-instance-identifier carshub-db-prod \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint}'

# Verify Lambda/EC2 is in same VPC and correct subnet
aws ec2 describe-instances \
  --instance-ids i-xxxx \
  --query 'Reservations[0].Instances[0].{VPC:VpcId,Subnet:SubnetId}'
```

### CloudFront Returning 403 on Media

```bash
# Verify OAC is attached to distribution
aws cloudfront get-distribution --id <distribution-id> \
  --query 'Distribution.DistributionConfig.Origins'

# Verify S3 bucket policy allows CloudFront service principal
aws s3api get-bucket-policy --bucket carshub-media-bucketprod-us-east-1
```

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Run validation: `terraform fmt -recursive && terraform validate`
4. Commit: `git commit -m 'feat: your feature description'`
5. Push and open a Pull Request

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

*Built with ❤️ using Terraform and AWS*

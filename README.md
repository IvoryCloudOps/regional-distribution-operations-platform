- #🚚 Regional Distribution Operations Platform

> **Status:** In Progress
> **Focus:** AWS • Terraform • Linux • Networking • Cloud Operations • CI/CD • Monitoring • Troubleshooting

A hands-on cloud engineering portfolio project that simulates the AWS infrastructure behind a regional distribution company’s internal order and inventory platform.

The goal is not to build a huge warehouse-management application. The application itself is intentionally lightweight.

The real focus is the infrastructure and operations work around it:

* designing the AWS architecture
* provisioning it with Terraform
* operating Linux workloads
* securing private infrastructure
* monitoring system health
* automating infrastructure changes
* troubleshooting infrastructure and application issues
* testing recovery procedures

---

## 🎯 Project Goal

This project is designed around skills that repeatedly appear in junior and associate-level cloud engineering, AWS administration, CloudOps, and DevOps job postings.

The objective is to demonstrate practical experience with a strong concentration of:

* AWS
* Terraform / Infrastructure as Code
* VPC networking
* EC2
* Linux administration
* IAM
* Application Load Balancing
* Auto Scaling
* RDS
* S3
* Systems Manager
* CloudWatch
* SNS
* Secrets Manager
* Git / GitHub
* CI/CD
* backup and recovery
* troubleshooting
* scaling
* cost-aware architecture
* Python/Boto3 automation

The goal is to demonstrate the ability to:

> **Design, build, operate, troubleshoot, and evolve an AWS-hosted business workload.**

---

# 🏢 Business Scenario

A regional distribution company operates several warehouses and distribution facilities in Georgia.

Approximately **200–300 employees** use an internal web application throughout the workday for tasks such as:

* inventory lookup
* order processing
* shipment-status tracking
* warehouse operations
* basic internal reporting

The platform is used consistently throughout the business day and experiences heavier demand during:

* month-end processing
* busy fulfillment periods
* seasonal demand increases

The company wants to migrate this system into AWS while improving:

* reliability
* security
* scalability
* visibility
* recoverability
* infrastructure consistency

The first design runs in **one AWS Region across two Availability Zones**.

---

# 🔐 Access Model

The application is **internal-only**.

It should not be directly available to the general internet.

Remote employees access the environment through:

**AWS Client VPN**

Primary application flow:

```text
Authorized Employee
        ↓
AWS Client VPN
        ↓
Internal Application Load Balancer
        ↓
Private Linux EC2 Application Tier
        ↓
Amazon RDS
```

The application servers and database remain private.

---

# ☁️ Architecture

The initial architecture uses a traditional multi-tier AWS design so the project can provide hands-on experience with networking, Linux, compute, load balancing, databases, monitoring, and cloud operations.

```text
                            Authorized Employee
                                    │
                                    ▼
                             AWS Client VPN
                                    │
                                    ▼
                      Internal Application Load Balancer
                              /               \
                             /                 \
                            ▼                   ▼
                     EC2 App Server       EC2 App Server
                          AZ-A                  AZ-B
                             \                 /
                              \               /
                                  Amazon RDS
                                   Multi-AZ
```

Supporting services include:

```text
Terraform
IAM
Systems Manager
CloudWatch
SNS
S3
Secrets Manager
NAT Gateway
Internet Gateway
GitHub Actions
```

---

# 🌐 Network Design

The environment is deployed across **two Availability Zones**.

Each AZ contains:

* a public subnet
* a private application subnet
* a private database subnet

Conceptually:

```text
AWS Region
│
├── Availability Zone A
│   ├── Public Subnet A
│   ├── Private Application Subnet A
│   └── Private Database Subnet A
│
└── Availability Zone B
    ├── Public Subnet B
    ├── Private Application Subnet B
    └── Private Database Subnet B
```

The application tier and database tier are not directly exposed to the public internet.

---

# 🖥️ Compute

The first application tier uses:

**Amazon EC2 running Linux**

The EC2 instances:

* run in private subnets
* do not have public IP addresses
* span two Availability Zones
* register with an internal Application Load Balancer
* are managed through an Auto Scaling Group
* are administered through AWS Systems Manager

This design intentionally creates hands-on Linux and cloud-operations practice around:

* systemd service management
* application startup and bootstrap
* logs and journal investigation
* permissions
* networking
* application health
* troubleshooting

---

# 📈 Scaling Strategy

The workload includes both predictable and unpredictable demand.

## Scheduled Scaling

Scheduled scaling is used for known traffic increases such as:

* weekday business-hour demand

```text
Known Demand Increase
        ↓
Scheduled Scaling
        ↓
Capacity Added Before Traffic Arrives
```

## Dynamic Scaling

Dynamic scaling is used for unexpected demand increases.

The implemented dynamic scaling policy uses:

* Auto Scaling Group average EC2 CPU utilization
* a 60% target-tracking threshold

```text
Unexpected Demand
        ↓
CloudWatch Metric
        ↓
Dynamic Scaling Policy
        ↓
Auto Scaling Group
```

---

# 💾 Data Layer

Structured business data is stored in:

**Amazon RDS**

The workload includes relational data such as:

* customers
* orders
* order items
* products
* inventory
* warehouses
* shipments

Example relationship:

```text
Customer
   ↓
Order
   ↓
Order Items
   ↓
Products / Inventory
   ↓
Shipment
```

RDS is deployed privately and uses a Multi-AZ configuration for availability.

---

# 📦 Object Storage

**Amazon S3** is used by the project for:

* application release artifacts used during EC2 bootstrap
* generated inventory report exports
* generated order report exports

The S3 bucket is:

* private
* encrypted
* versioned
* protected by S3 public-access blocking

---

# 🛡️ Security

The platform follows a least-privilege model.

Security areas include:

* IAM roles and policies
* security groups
* private application/database tiers
* Systems Manager instead of public SSH
* Secrets Manager
* encryption
* restricted database connectivity
* controlled employee access through Client VPN

### Security Group Flow

```text
Client VPN
   ↓
Internal ALB Security Group
   ↓
Application Security Group
   ↓
Database Security Group
```

The database only accepts connections from the application tier.

---

# 🔑 Secrets Management

Database credentials and sensitive configuration should not live directly in:

* application source code
* GitHub
* Terraform files
* EC2 configuration

**AWS Secrets Manager** stores sensitive values required by the application.

The application retrieves the RDS-managed database credentials from Secrets Manager at runtime rather than storing database credentials directly in source code.

---

# 🔧 Administrative Access

Private EC2 instances are managed using:

**AWS Systems Manager Session Manager**

```text
Cloud Administrator
        ↓
AWS Systems Manager
        ↓
Private EC2
```

No public SSH exposure is required.

---

# 🌍 Outbound Internet Access

Private EC2 instances require outbound connectivity for:

* Linux package updates
* operating-system maintenance
* software dependencies

The initial architecture uses:

**One NAT Gateway**

```text
Private EC2
    ↓
NAT Gateway
    ↓
Internet Gateway
    ↓
Internet
```

### Cost Tradeoff

One NAT Gateway is intentionally used rather than one per Availability Zone.

This reduces cost but creates a known resilience tradeoff for outbound connectivity.

A higher-availability production design could use one NAT Gateway per AZ.

---

# 📊 Monitoring & Observability

**Amazon CloudWatch** provides infrastructure metric monitoring and alarms for the deployed platform.

The implemented Terraform monitoring covers:

* **Application Load Balancer:** unhealthy target count
* **EC2 / Auto Scaling Group:** average CPU utilization, with an alarm at 80%
* **Amazon RDS:** CPU utilization, with an alarm at 80%
* **Amazon RDS:** free storage space, with an alarm when available storage falls to 5 GB or less

These alarms are defined in `terraform/monitoring.tf`.

---

# 🚨 Alerting

CloudWatch alarms publish notifications to an **Amazon SNS** topic.

```text
Problem Detected
      ↓
CloudWatch Alarm
      ↓
Amazon SNS
      ↓
Operations Email Notification
```

Implemented alerts include:

* unhealthy ALB targets
* high EC2 / Auto Scaling Group CPU utilization
* high RDS CPU utilization
* low RDS free storage

---

# 💽 Backup & Recovery

### Amazon RDS

Configured recovery capabilities include:

* 7-day automated backup retention
* RDS snapshots
* point-in-time recovery support within the backup-retention window

### Amazon S3

S3 versioning provides object-version history that can be used to recover overwritten or deleted objects.

RDS backup and recovery procedures are documented in:

```text
docs/runbooks/rds_backup_recovery.md
```

---

# 🧱 Infrastructure as Code

AWS infrastructure is provisioned using:

**Terraform**

Terraform manages resources such as:

* VPC
* subnets
* route tables
* Internet Gateway
* NAT Gateway
* security groups
* Client VPN resources
* internal ALB
* target groups
* EC2
* launch templates
* Auto Scaling Group
* IAM
* RDS
* S3
* CloudWatch
* SNS
* Secrets Manager

---

# 🔄 CI/CD

The repository includes a GitHub Actions workflow for Terraform validation and planning.

Implemented flow:

```text
Git Push / Pull Request
   ↓
GitHub Actions
   ↓
OIDC Authentication to AWS
   ↓
terraform fmt -check
   ↓
terraform init
   ↓
terraform validate
   ↓
terraform plan
```

GitHub Actions uses AWS OIDC federation for temporary credentials rather than long-lived AWS access keys.

The project does **not** currently include an automated Terraform apply workflow.

---

# 🐧 Linux Operations

The private Amazon Linux 2023 EC2 tier provides hands-on operating-system and application operations experience.

Implemented areas include:

* systemd service management for the Flask application
* package and dependency installation through EC2 bootstrap/user data
* application startup and service troubleshooting
* journal/system log investigation
* network and application-health troubleshooting
* Systems Manager administration without public SSH

---

# 🤖 Automation

The repository includes a Python/Boto3 operational audit script at:

```text
scripts/platform_audit.py
```

The script checks:

* Auto Scaling Group capacity and instance health
* ALB target-group health
* RDS database availability/status

and reports an overall platform health state without hardcoded AWS credentials.

---

# 💰 Cost-Aware Architecture

The project intentionally balances:

* reliability
* security
* operational simplicity
* cost

Current design decisions include:

* two Availability Zones instead of three
* one NAT Gateway initially
* appropriately sized EC2 instances
* appropriately sized RDS
* Auto Scaling instead of permanently running peak capacity
* scheduled scaling for predictable spikes
* dynamic scaling for unexpected demand

---

# 🗂️ Repository Structure

```text
regional-distribution-operations-platform/
│
├── README.md
├── .gitignore
│
├── terraform/
│
├── application/
│
├── scripts/
│
├── docs/
│   └── runbooks/
│
└── .github/
    └── workflows/
```

---

# 🚧 Current Progress

- [x] Business scenario defined
- [x] Architecture requirements defined
- [x] Access model selected
- [x] Two-AZ design selected
- [x] EC2/Linux compute model selected
- [x] Relational data model selected
- [x] Scaling strategy defined
- [x] Single-NAT cost tradeoff defined

## 🌐 Networking & Access

- [x] Terraform network foundation
- [x] VPC and six-subnet architecture
- [x] Internet Gateway
- [x] Single NAT Gateway
- [x] Public, application, and database route tables
- [x] Security groups
- [x] AWS Client VPN infrastructure
- [x] Local Client VPN connection troubleshooting

## 🖥️ Compute & Load Balancing

- [x] EC2 application tier
- [x] Amazon Linux 2023 launch template
- [x] Auto Scaling Group
- [x] Multi-AZ application instances
- [x] Systems Manager access
- [x] Application bootstrap with user data
- [x] Internal Application Load Balancer
- [x] Target group and health checks
- [x] ASG integration with ALB

## 🗄️ Data & Storage

- [x] RDS MySQL
- [x] Multi-AZ RDS deployment
- [x] Private database subnet group
- [x] RDS-managed Secrets Manager credentials
- [x] S3 application storage
- [x] S3 encryption
- [x] S3 versioning
- [x] S3 public-access blocking

## 🔐 IAM & Security

- [x] EC2 IAM role
- [x] Systems Manager permissions
- [x] Least-privilege S3 application permissions
- [x] Least-privilege Secrets Manager read permissions
- [x] Application retrieval of database secret

## ⚙️ Terraform & CI/CD

- [x] Terraform-managed infrastructure
- [x] GitHub repository structure
- [x] Terraform CI workflow
- [x] Automated Terraform formatting check
- [x] Automated Terraform validation
- [ ] Remote Terraform state
- [ ] GitHub Actions AWS OIDC authentication
- [ ] Automated Terraform plan
- [ ] Controlled Terraform apply workflow

## 📊 Operations

- [x] CloudWatch monitoring
- [x] SNS alerting
- [x] Scheduled Auto Scaling
- [ ] Dynamic Auto Scaling
- [x] Runbooks
- [ ] Python/Boto3 automation

---

# 📌 Project Philosophy

This project is intentionally **not** a giant enterprise application.

The application is small.

The engineering around it is the point.

Every AWS service should answer:

> **What business, reliability, security, operational, or engineering requirement made this resource necessary?**

The goal is not to collect AWS services.

The goal is to build evidence of practical cloud engineering ability.

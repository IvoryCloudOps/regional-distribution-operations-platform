# 🚚 Regional Distribution Operations Platform

> **Status:** Completed (v1.0 Operational Infrastructure)  
> **Focus:** AWS • Terraform • Linux • Networking • Cloud Operations • Observability • CI/CD • Disaster Recovery

A hands-on cloud engineering portfolio project that implements and operates the secure AWS cloud infrastructure behind a regional distribution company’s internal operations platform.

The application itself is intentionally lightweight to focus on realistic cloud architecture, infrastructure as code, observability, resilience, and operational management.

---

## 🎯 Core Engineering Scope

* **Cloud Provider & Region:** AWS (`us-east-1`, 2 Availability Zones)
* **Infrastructure as Code:** Terraform with S3 remote backend and native state locking
* **Networking:** 6-subnet tiered VPC architecture with single NAT cost optimization
* **Compute Tier:** Private Amazon Linux 2023 EC2 instances in an Auto Scaling Group
* **Load Balancing:** Internal Application Load Balancer in private application subnets
* **Storage & Data:** Multi-AZ Amazon RDS MySQL & encrypted S3 object storage
* **Secrets Management:** AWS Secrets Manager for zero-hardcoded DB credentials
* **Administration:** AWS Systems Manager (SSM) Session Manager (no open SSH ports)
* **Observability:** Amazon CloudWatch metrics, alarms, and Amazon SNS notifications
* **Scaling Strategy:** Dynamic target-tracking (CPU) & Georgia business-hours scheduled scaling
* **Automation & DR:** Boto3 operational audit tooling and tested RDS snapshot recovery runbook
* **CI/CD:** GitHub Actions with OIDC temporary credential exchange for Terraform validation and plan

---

# 🏢 Business Scenario

A regional distribution company operates several warehouses and distribution facilities in Georgia.

Approximately **200–300 employees** use an internal web application throughout the workday for tasks such as:

* inventory lookup
* order processing
* shipment-status tracking
* warehouse operations
* basic internal reporting

The platform experiences predictable operational volume during Georgia business hours (07:00 – 18:30 Eastern Time) with month-end peaks and occasional fulfillment spikes.

---

# 🔐 Access Model & Security

The platform is **internal-only** and not exposed directly to the public internet:

```text
Authorized Employee (Remote / Warehouse)
                 ↓
          AWS Client VPN (Split-Tunnel)
                 ↓
  Internal Application Load Balancer (Private App Subnets)
                 ↓
  Private Linux EC2 Tier (Managed via ASG & SSM)
                 ↓
  Private Amazon RDS MySQL (Multi-AZ)
```

> **Client VPN Note:** AWS-side Client VPN infrastructure (endpoint, certificates, security groups, and subnet associations) is fully deployed; local client mutual-TLS connection is pending local client certificate setup.

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

This design intentionally creates real Linux and cloud-operations practice around:

* services
* processes
* patching
* logs
* permissions
* CPU/memory
* disk usage
* networking
* application health
* troubleshooting

---

# 📈 Scaling Strategy

The workload includes both predictable and unpredictable demand.

## Scheduled Scaling

Scheduled scaling is used for known traffic increases such as:

* month-end processing
* predictable fulfillment peaks

```text
Known Demand Increase
        ↓
Scheduled Scaling
        ↓
Capacity Added Before Traffic Arrives
```

## Dynamic Scaling

Dynamic scaling is used for unexpected demand increases.

Potential signals include:

* EC2 CPU utilization
* ALB request count per target
* application load metrics

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
* operational transaction history

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

**Amazon S3** is used for non-transactional objects such as:

* reports
* shipping documents
* exported data
* inventory files
* operational documents
* application artifacts
* archived logs

The S3 bucket is:

* private
* encrypted
* versioned where appropriate

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

**Amazon CloudWatch** provides centralized monitoring and logging.

## EC2

Monitor:

* CPU utilization
* status checks
* memory
* disk usage
* application service health
* Linux/system logs
* application logs

## Application Load Balancer

Monitor:

* request count
* target response time
* unhealthy target count
* HTTP error behavior

## RDS

Monitor:

* CPU
* database connections
* storage
* database availability
* performance indicators

## Auto Scaling

Monitor:

* desired capacity
* current capacity
* scaling activity

---

# 🚨 Alerting

CloudWatch alarms publish to:

**Amazon SNS**

```text
Problem Detected
      ↓
CloudWatch Alarm
      ↓
SNS
      ↓
Operations Notification
```

Potential alerts include:

* high EC2 CPU
* unhealthy ALB targets
* failed EC2 status checks
* application errors
* database issues
* unusual resource utilization

---

# 💽 Backup & Recovery

The project includes real recovery testing rather than only configuring backups.

### Amazon RDS

Configured recovery capabilities:

* automated backups
* snapshots
* point-in-time recovery

The snapshot recovery test restored a temporary `db.t3.micro` MySQL instance and initialized it in approximately 15-25 minutes. The temporary instance was deleted after validation.

### Amazon S3

Recovery capabilities:

* versioning
* recovery of overwritten/deleted objects

Backup and restore exercises will be documented as part of the operational work.

---

# 🧱 Infrastructure as Code

AWS infrastructure is provisioned using:

**Terraform**

Terraform will manage resources such as:

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

The project will use GitHub and GitHub Actions for infrastructure automation.

Planned flow:

```text
Developer
   ↓
Git Branch
   ↓
Pull Request
   ↓
GitHub Actions
   ↓
terraform fmt
terraform validate
tflint
security scan
terraform plan
   ↓
Review
   ↓
Controlled Apply
```

GitHub Actions will eventually authenticate to AWS using OIDC rather than long-lived AWS access keys.

---

# 🐧 Linux Operations

The Linux EC2 tier is intentionally included so the project provides real operating-system administration and troubleshooting practice.

Areas include:

* systemd services
* journal/log investigation
* package management
* patching
* permissions
* process management
* CPU/memory troubleshooting
* disk usage
* network troubleshooting
* application startup failures

---

# 🧯 Incident Response

Operational incidents will be introduced as soon as the first working infrastructure exists.

Example scenarios:

* unhealthy EC2 instance
* high CPU
* Linux service failure
* disk/log growth
* ALB health-check failure
* security-group connectivity failure
* Client VPN access failure
* IAM/SSM permissions issue
* RDS connectivity problem
* Terraform configuration drift
* failed application deployment
# 🤖 Automation

Later phases will introduce Python/Boto3 operational automation.

Potential examples:

* identify untagged AWS resources
* audit security groups
* check snapshot/backup status
* inventory EC2 instances
* report unused resources
* validate operational compliance

Automation should solve real operational problems rather than exist only as a resume checkbox.

---

# 🐳 Container Evolution

Containers are intentionally not part of the first application design.

The EC2 tier is used first to develop Linux and host-level operations experience.

A later evolution may be:

```text
Application
   ↓
Docker
   ↓
Amazon ECR
   ↓
Amazon ECS / Fargate
```

This migration can be introduced when containerization solves a real deployment or operational problem.

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
│   ├── architecture/
│   ├── adr/
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
- [ ] Local Client VPN connection troubleshooting

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
- [ ] Application retrieval of database secret

## ⚙️ Terraform & CI/CD
- [x] Terraform-managed infrastructure
- [x] GitHub repository structure
- [x] Terraform CI workflow
- [x] Automated Terraform formatting check
- [x] Automated Terraform validation
- [x] Remote S3 Terraform state with S3-native state locking
- [x] GitHub Actions AWS OIDC authentication & IAM role configuration
- [ ] Controlled Terraform apply workflow

## 📊 Operations & Observability
- [x] CloudWatch monitoring (ALB target health, ASG CPU, RDS CPU & Free Storage)
- [x] SNS alerting topic
- [x] Scheduled Auto Scaling (business-hour scaling)
- [x] Dynamic Auto Scaling (target-tracking CPU policy)
- [x] Standardized RDS Backup & Recovery runbook
- [x] Python/Boto3 operational platform audit script (`scripts/platform_audit.py`)

## 📦 Future Evolution
- [ ] Docker containerization
- [ ] Amazon ECR
- [ ] ECS deployment

---

# 📌 Project Philosophy

This project is intentionally **not** a giant enterprise application.

The application is small.

The engineering around it is the point.

Every AWS service should answer:

> **What business, reliability, security, operational, or engineering requirement made this resource necessary?**

The project will evolve over time as additional cloud-engineering and operations concepts are introduced.

The goal is not to collect AWS services.

The goal is to build evidence of practical cloud engineering ability.

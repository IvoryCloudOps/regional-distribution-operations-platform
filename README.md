# 🚚 Regional Distribution Operations Platform

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
* troubleshooting incidents
* testing recovery procedures
* improving the design over time

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
* incident response
* scaling
* cost-aware architecture
* Python/Boto3 automation
* Docker/ECS later in the project

The long-term goal is to demonstrate the ability to:

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

Planned recovery capabilities:

* automated backups
* snapshots
* point-in-time recovery

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
* Auto Scaling failure
* backup/restore exercise
* unexpected infrastructure cost

Each incident should follow:

```text
Detection
   ↓
Investigation
   ↓
Root Cause
   ↓
Remediation
   ↓
Validation
   ↓
Prevention
```

Incident documentation will be stored under:

```text
docs/incidents/
```

---

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
│   ├── incidents/
│   └── runbooks/
│
└── .github/
    └── workflows/
```

---

# 🚧 Current Progress

* [x] Business scenario defined
* [x] Architecture requirements defined
* [x] Access model selected
* [x] Two-AZ design selected
* [x] EC2/Linux compute model selected
* [x] Relational data model selected
* [x] Scaling strategy defined
* [x] Single-NAT cost tradeoff defined
* [ ] Terraform network foundation
* [ ] Security groups
* [ ] EC2 application tier
* [ ] Application Load Balancer
* [ ] RDS
* [ ] S3
* [ ] Systems Manager
* [ ] CloudWatch monitoring
* [ ] SNS alerting
* [ ] Secrets Manager
* [ ] CI/CD
* [ ] First operational incident
* [ ] Backup/recovery exercise
* [ ] Python/Boto3 automation
* [ ] Docker/ECS evolution

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

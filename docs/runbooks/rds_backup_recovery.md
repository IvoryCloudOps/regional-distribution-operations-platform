# Database Backup & Recovery Runbook

## Overview
This runbook defines the backup validation and disaster recovery procedure for the Regional Distribution Operations Platform Multi-AZ MySQL RDS database (`distribution-mysql`).

* **RPO (Recovery Point Objective):** $\le 5\text{ minutes}$ (continuous binary transaction logs backed by RDS automated backup system).
* **RTO (Recovery Time Objective):** $\approx 15\text{–}25\text{ minutes}$ (empirical time observed to provision and initialize a restored `db.t3.micro` instance from snapshot).

---

## 1. Automated Backups Configuration
- **Retention Period:** 7 days
- **Backup Window:** Automatic daily window managed by AWS RDS.
- **Storage Redundancy:** Replicated across multiple AZs via Multi-AZ deployment.

---

## 2. Recovery Test Record
- **Result:** A snapshot was restored to a temporary `db.t3.micro` MySQL instance and initialized successfully in approximately 15-25 minutes.
- **Cleanup:** The temporary restore was deleted after validation.

---

## 3. On-Demand Manual Snapshot Procedure

To capture a point-in-time manual snapshot prior to maintenance or major deployments:

```bash
aws rds create-db-snapshot \
    --db-instance-identifier distribution-mysql \
    --db-snapshot-identifier distribution-mysql-manual-validation \
    --region us-east-1
```

---

## 4. Restoration & Validation Procedure

### Step 1: Restore to a Temporary Validation Instance
AWS RDS provisions a separate independent instance from a snapshot to avoid modifying active production workloads:

```bash
aws rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier distribution-mysql-temp-restore \
    --db-snapshot-identifier distribution-mysql-manual-validation \
    --db-subnet-group-name distribution-db-subnet-group \
    --vpc-security-group-ids <DB_SECURITY_GROUP_ID> \
    --no-publicly-accessible \
    --region us-east-1
```

### Step 2: Validate Data & Service Health
1. Monitor status until `DBInstanceStatus` is `available`:
   ```bash
   aws rds describe-db-instances --db-instance-identifier distribution-mysql-temp-restore --query "DBInstances[0].DBInstanceStatus"
   ```
2. Verify endpoint resolution and database engine parameter integrity.

### Step 3: Cleanup Temporary Restored Instance
Once recovery is validated, terminate the temporary instance immediately to prevent ongoing costs:
```bash
aws rds delete-db-instance \
    --db-instance-identifier distribution-mysql-temp-restore \
    --skip-final-snapshot \
    --region us-east-1
```

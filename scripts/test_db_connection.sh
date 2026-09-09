#!/bin/bash
#-------------------------------------------------------------------------------
# Regional Distribution Operations Platform - DB Connection & Secret Test
# Usage: Run directly on any application EC2 instance via AWS SSM Session Manager
# Purpose: Proves IAM role -> Secrets Manager retrieval -> MySQL port 3306 query
#-------------------------------------------------------------------------------

echo "=== Testing AWS Secrets Manager Retrieval ==="
SECRET_NAME="rds!db-cbeea3fe-3f0e-4ab8-9571-067df76f14a8" # Or discover dynamically

SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --region us-east-1 --query SecretString --output text 2>/dev/null)

if [ -z "$SECRET_JSON" ]; then
  # Fallback: lookup by tag or RDS secret prefix
  SECRET_ARN=$(aws secretsmanager list-secrets --region us-east-1 --filter Key="name",Values="rds!db" --query "SecretList[0].ARN" --output text 2>/dev/null)
  SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --region us-east-1 --query SecretString --output text 2>/dev/null)
fi

if [ -n "$SECRET_JSON" ]; then
  echo "[SUCCESS] Retrieved database secret from AWS Secrets Manager using IAM instance profile."
  DB_USER=$(echo "$SECRET_JSON" | grep -o '"username":"[^"]*' | cut -d'"' -f4)
  DB_PASS=$(echo "$SECRET_JSON" | grep -o '"password":"[^"]*' | cut -d'"' -f4)
  DB_HOST=$(echo "$SECRET_JSON" | grep -o '"host":"[^"]*' | cut -d'"' -f4)
  DB_PORT=$(echo "$SECRET_JSON" | grep -o '"port":[^,]*' | cut -d':' -f2 | tr -d ' }')
  
  echo "Database Host: $DB_HOST"
  echo "Database User: $DB_USER"
  echo "Database Port: ${DB_PORT:-3306}"
  
  echo -e "\n=== Testing MySQL Network Connectivity (Port 3306) ==="
  if nc -z -v -w5 "$DB_HOST" 3306 2>/dev/null || (echo > /dev/tcp/"$DB_HOST"/3306) 2>/dev/null; then
    echo "[SUCCESS] TCP port 3306 is reachable from application subnet to RDS private subnet."
  else
    echo "[INFO] Testing connectivity via mysql client if installed..."
  fi
  
  if command -v mysql &>/dev/null; then
    echo -e "\n=== Executing Test Query ==="
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1 AS operational_check, NOW() AS db_time;" 2>/dev/null
    if [ $? -eq 0 ]; then
      echo "[SUCCESS] Successfully authenticated and executed test query against MySQL RDS!"
    fi
  fi
else
  echo "[ERROR] Failed to retrieve secret from Secrets Manager. Check IAM permissions."
fi

#!/bin/bash
# EC2 bootstrap for the distribution-app Auto Scaling Group launch template.
# Terraform (compute.tf) renders this as a template; ${s3_bucket}, ${aws_region},
# ${db_secret_arn}, and ${db_name} are substituted at plan/apply time and are not secrets.
set -euxo pipefail

dnf install -y python3 python3-pip unzip

mkdir -p /opt/distribution-app

# Application code is packaged and uploaded to S3 via scripts/package_app.sh (see application/README.md).
aws s3 cp s3://${s3_bucket}/app-releases/distribution-app.zip /tmp/distribution-app.zip --region ${aws_region}
# unzip exit code 1 is a non-fatal warning (e.g. backslash path separators from Windows-built zips); only >=2 is a real failure.
set +e
unzip -o /tmp/distribution-app.zip -d /opt/distribution-app
unzip_exit=$?
set -e
if [ "$unzip_exit" -gt 1 ]; then
  echo "unzip failed with exit code $unzip_exit" >&2
  exit 1
fi

cat > /etc/distribution-app.env <<EOF
DB_SECRET_ARN=${db_secret_arn}
DB_NAME=${db_name}
DB_HOST=${db_host}
DB_PORT=${db_port}
S3_BUCKET=${s3_bucket}
AWS_REGION=${aws_region}
EOF
chmod 600 /etc/distribution-app.env

cd /opt/distribution-app
python3 -m venv venv
venv/bin/pip install --upgrade pip
venv/bin/pip install -r requirements.txt

cp /opt/distribution-app/distribution-app.service /etc/systemd/system/distribution-app.service
systemctl daemon-reload
systemctl enable --now distribution-app


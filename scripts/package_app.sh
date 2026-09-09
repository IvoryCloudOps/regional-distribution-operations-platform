#!/bin/bash
# Packages application/ into distribution-app.zip for upload to the project's S3 bucket.
# Run from a bash shell (Git Bash / WSL / Linux / macOS). Requires `zip`.
#
# Usage:
#   ./scripts/package_app.sh
#   aws s3 cp distribution-app.zip s3://<bucket-name>/app-releases/distribution-app.zip
#
# Find <bucket-name> with: terraform output s3_bucket_name

set -euo pipefail
cd "$(dirname "$0")/.."

rm -f distribution-app.zip
(cd application && zip -r ../distribution-app.zip . -x "venv/*" -x "__pycache__/*" -x "*.pyc")

echo "Created distribution-app.zip"
echo "Upload with: aws s3 cp distribution-app.zip s3://<bucket-name>/app-releases/distribution-app.zip"

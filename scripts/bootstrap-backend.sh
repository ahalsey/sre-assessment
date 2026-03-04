#!/usr/bin/env bash
##############################################################################
# Run before initializing environments to create TF state.
##############################################################################

set -euo pipefail

PROJECT_NAME="${1:-platform-sre-demo}"
AWS_REGION="${2:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

BUCKET_NAME="${PROJECT_NAME}-tfstate-${ACCOUNT_ID}"
TABLE_NAME="${PROJECT_NAME}-tfstate-lock"

echo "==> Creating S3 bucket: ${BUCKET_NAME}"
aws s3api create-bucket \
  --bucket "${BUCKET_NAME}" \
  --region "${AWS_REGION}" \
  $([ "${AWS_REGION}" != "us-east-1" ] && echo "--create-bucket-configuration LocationConstraint=${AWS_REGION}" || echo "")

aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [{ "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "aws:kms" } }]
  }'

aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "==> Creating DynamoDB table: ${TABLE_NAME}"
aws dynamodb create-table \
  --table-name "${TABLE_NAME}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${AWS_REGION}" 2>/dev/null || echo "Table already exists"

echo ""
echo "==> Done. Add these to your GitHub secrets:"
echo "    TF_STATE_BUCKET = ${BUCKET_NAME}"
echo "    TF_LOCK_TABLE   = ${TABLE_NAME}"

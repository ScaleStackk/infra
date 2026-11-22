#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI is required. Nothing was installed or deployed." >&2
  exit 1
fi

STACK_NAME="${STACK_NAME:-questacase-demo-upload}"
AWS_REGION_NAME="${AWS_REGION_NAME:-ap-south-1}"
ENVIRONMENT_NAME="${ENVIRONMENT_NAME:-demo}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.small}"
FIREBASE_ORIGIN="${FIREBASE_ORIGIN:-https://questacase.web.app}"
FIREBASE_AUTH_ORIGIN="${FIREBASE_AUTH_ORIGIN:-https://questacase.firebaseapp.com}"

parameters=(
  "EnvironmentName=$ENVIRONMENT_NAME"
  "InstanceType=$INSTANCE_TYPE"
  "FirebaseOrigin=$FIREBASE_ORIGIN"
  "FirebaseAuthOrigin=$FIREBASE_AUTH_ORIGIN"
)

if [[ -n "${JUDGMENT_BUCKET_NAME:-}" ]]; then
  parameters+=("JudgmentBucketName=$JUDGMENT_BUCKET_NAME")
fi

if [[ -n "${API_DOMAIN_NAME:-}" || -n "${ROUTE53_HOSTED_ZONE_ID:-}" ]]; then
  : "${API_DOMAIN_NAME:?Set both API_DOMAIN_NAME and ROUTE53_HOSTED_ZONE_ID}"
  : "${ROUTE53_HOSTED_ZONE_ID:?Set both API_DOMAIN_NAME and ROUTE53_HOSTED_ZONE_ID}"
  parameters+=(
    "ApiDomainName=$API_DOMAIN_NAME"
    "Route53HostedZoneId=$ROUTE53_HOSTED_ZONE_ID"
  )
fi

if [[ -n "${WEBAPI_REPOSITORY_URL:-}" || -n "${KAFKA_REPOSITORY_URL:-}" ]]; then
  : "${WEBAPI_REPOSITORY_URL:?Set both WEBAPI_REPOSITORY_URL and KAFKA_REPOSITORY_URL}"
  : "${KAFKA_REPOSITORY_URL:?Set both WEBAPI_REPOSITORY_URL and KAFKA_REPOSITORY_URL}"
  parameters+=(
    "WebApiRepositoryUrl=$WEBAPI_REPOSITORY_URL"
    "WebApiRepositoryBranch=${WEBAPI_REPOSITORY_BRANCH:-main}"
    "KafkaRepositoryUrl=$KAFKA_REPOSITORY_URL"
    "KafkaRepositoryBranch=${KAFKA_REPOSITORY_BRANCH:-main}"
  )
fi

aws cloudformation deploy \
  --region "$AWS_REGION_NAME" \
  --stack-name "$STACK_NAME" \
  --template-file "$SCRIPT_DIR/phase1-upload-stack.yaml" \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides "${parameters[@]}" \
  --tags Project=QuestaCase Environment="$ENVIRONMENT_NAME"

aws cloudformation describe-stacks \
  --region "$AWS_REGION_NAME" \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs' \
  --output table

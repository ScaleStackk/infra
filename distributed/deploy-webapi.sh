#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI is required. Nothing was installed or deployed." >&2
  exit 1
fi

: "${INFERENCE_REPOSITORY_URL:=https://github.com/ScaleStackk/inference.git}"
: "${JUDGMENT_BUCKET_NAME:?Set JUDGMENT_BUCKET_NAME}"
: "${KAFKA_BROKERS:?Set KAFKA_BROKERS}"
: "${INFERENCE_NODES:?Set INFERENCE_NODES to the participant private endpoints}"

aws cloudformation deploy \
  --region "${AWS_REGION_NAME:-ap-south-2}" \
  --stack-name "${STACK_NAME:-questacase-webapi-node}" \
  --template-file "$SCRIPT_DIR/webapi-node-stack.yaml" \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    "EnvironmentName=${ENVIRONMENT_NAME:-demo}" \
    "VpcCidr=${VPC_CIDR:-10.10.0.0/16}" \
    "PublicSubnetCidr=${PUBLIC_SUBNET_CIDR:-10.10.1.0/24}" \
    "InstanceType=${INSTANCE_TYPE:-t3.medium}" \
    "RootVolumeSize=${ROOT_VOLUME_SIZE:-30}" \
    "ApiIngressCidr=${API_INGRESS_CIDR:-10.10.0.0/16}" \
    "WebApiRepositoryUrl=${WEBAPI_REPOSITORY_URL:-https://github.com/ScaleStackk/webapi.git}" \
    "WebApiRepositoryBranch=${WEBAPI_REPOSITORY_BRANCH:-main}" \
    "InferenceRepositoryUrl=$INFERENCE_REPOSITORY_URL" \
    "InferenceRepositoryBranch=${INFERENCE_REPOSITORY_BRANCH:-main}" \
    "JudgmentBucketName=$JUDGMENT_BUCKET_NAME" \
    "KafkaBrokers=$KAFKA_BROKERS" \
    "InferenceNodes=$INFERENCE_NODES" \
    "EmbeddingApiUrl=${EMBEDDING_API_URL:-}" \
    "EmbeddingApiKey=${EMBEDDING_API_KEY:-}" \
    "QdrantUrl=${QDRANT_URL:-}" \
    "QdrantApiKey=${QDRANT_API_KEY:-}" \
    "Neo4jUrl=${NEO4J_URL:-}" \
    "Neo4jPassword=${NEO4J_PASSWORD:-}" \
    "InferenceModel=${INFERENCE_MODEL:-qwen3:4b}" \
  --tags Project=QuestaCase Environment="${ENVIRONMENT_NAME:-demo}"

aws cloudformation describe-stacks \
  --region "${AWS_REGION_NAME:-ap-south-2}" \
  --stack-name "${STACK_NAME:-questacase-webapi-node}" \
  --query 'Stacks[0].Outputs' \
  --output table

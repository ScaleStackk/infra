#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI is required. Nothing was installed or deployed." >&2
  exit 1
fi

: "${INFERENCE_REPOSITORY_URL:=https://github.com/ScaleStackk/inference.git}"

aws cloudformation deploy \
  --region "${AWS_REGION_NAME:-ap-south-2}" \
  --stack-name "${STACK_NAME:-questacase-inference-node}" \
  --template-file "$SCRIPT_DIR/inference-node-stack.yaml" \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    "EnvironmentName=${ENVIRONMENT_NAME:-demo}" \
    "VpcCidr=${VPC_CIDR:-10.20.0.0/16}" \
    "PublicSubnetCidr=${PUBLIC_SUBNET_CIDR:-10.20.1.0/24}" \
    "InferenceIngressCidr=${INFERENCE_INGRESS_CIDR:-0.0.0.0/0}" \
    "InstanceType=${INSTANCE_TYPE:-g6.xlarge}" \
    "RootVolumeSize=${ROOT_VOLUME_SIZE:-60}" \
    "InferenceRepositoryUrl=$INFERENCE_REPOSITORY_URL" \
    "InferenceRepositoryBranch=${INFERENCE_REPOSITORY_BRANCH:-main}" \
    "OllamaModel=${OLLAMA_MODEL:-qwen3:4b}" \
    "InferenceImage=${INFERENCE_IMAGE:-questacase-inference:qwen3-4b}" \
  --tags Project=QuestaCase Environment="${ENVIRONMENT_NAME:-demo}"

aws cloudformation describe-stacks \
  --region "${AWS_REGION_NAME:-ap-south-2}" \
  --stack-name "${STACK_NAME:-questacase-inference-node}" \
  --query 'Stacks[0].Outputs' \
  --output table

#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
env_file="${QUESTACASE_LOCAL_ENV:-$script_dir/.env}"

if [[ ! -f "$env_file" ]]; then
  echo "Missing $env_file; the local stack has no configuration to stop." >&2
  exit 1
fi

docker compose --env-file "$env_file" --file "$script_dir/compose.local.yaml" down
echo "Local containers stopped. Kafka and local cache volumes were retained."
echo "AWS S3, Neo4j and Qdrant were not changed."

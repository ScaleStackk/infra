#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
env_file="${QUESTACASE_LOCAL_ENV:-$script_dir/.env}"
compose_file="$script_dir/compose.local.yaml"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required; nothing was installed." >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "Start Docker Desktop before running the local stack." >&2
  exit 1
fi
if [[ ! -f "$env_file" ]]; then
  cp "$script_dir/.env.example" "$env_file"
  echo "Created $env_file. Replace every replace-with-* value, then run this script again." >&2
  exit 1
fi
if grep -Eq '=replace-with-' "$env_file"; then
  echo "$env_file still contains placeholder credentials. Replace them before starting containers." >&2
  exit 1
fi

docker compose --env-file "$env_file" --file "$compose_file" config --quiet
docker compose --env-file "$env_file" --file "$compose_file" up --detach --wait --wait-timeout 600

echo "QuestaCase local processing is ready:"
echo "  Web app:       http://localhost:3000"
echo "  Web API:       http://localhost:8080/api/v1/health"
echo "  Ollama:        http://localhost:11434/api/tags"
echo "  HAProxy stats: http://localhost:8404/stats"
echo "AWS S3, Neo4j and Qdrant remain remote and are not managed by this stack."

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
  echo "Start Docker Desktop before building the local stack." >&2
  exit 1
fi
if [[ ! -f "$env_file" ]]; then
  cp "$script_dir/.env.example" "$env_file"
  echo "Created $env_file. Replace every replace-with-* value, then run this script again." >&2
  exit 1
fi

docker compose --env-file "$env_file" --file "$compose_file" config --quiet
docker compose --env-file "$env_file" --file "$compose_file" build
docker compose --env-file "$env_file" --file "$compose_file" pull webapp

echo "Local processing images are ready. Run $script_dir/run.sh next."

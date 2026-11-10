#!/usr/bin/env bash
# Builds the backend image locally on the home server and deploys it via the Coolify API.
# Usage: ./deploy.sh <tag>      (Coolify service oratge-backend, project "Oratge")
set -euo pipefail
cd "$(dirname "$0")"
TAG=${1:?tag, e.g. 3}
SU=6idpsledohf6sj0bncjiybt2
.venv/bin/python -m pytest -q
docker build -q -t "oratge-backend:$TAG" .
CT=$(infisical-get COOLIFY_API_TOKEN); H=hetzner-server.tailfd0b90.ts.net; RES="--resolve $H:8000:100.64.112.4"
B64=$(sed "s#image: oratge-backend:.*#image: oratge-backend:$TAG#" compose.yml | base64 -w0)
curl -sfk $RES -X PATCH -H "Authorization: Bearer $CT" -H "Content-Type: application/json" \
  -d "{\"docker_compose_raw\":\"$B64\"}" "https://$H:8000/api/v1/services/$SU" >/dev/null
curl -sfk $RES -X POST -H "Authorization: Bearer $CT" "https://$H:8000/api/v1/deploy?uuid=$SU&force=true"; echo
for i in $(seq 1 30); do
  sleep 4
  if curl -sf -m 5 http://100.96.0.121:8199/health >/dev/null; then echo "healthy (oratge-backend:$TAG)"; exit 0; fi
done
echo "not healthy after 2 min" >&2; exit 1

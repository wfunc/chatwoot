#!/bin/bash
set -euo pipefail

PROXY_URL="http://192.168.110.183:7890"

docker buildx build \
  --platform linux/amd64 \
  -f docker/Dockerfile \
  -t myuwhn/chatwoot:local \
  --build-arg NODE_OPTIONS="--max-old-space-size=8192 --openssl-legacy-provider" \
  --build-arg http_proxy="${PROXY_URL}" \
  --build-arg https_proxy="${PROXY_URL}" \
  --build-arg HTTP_PROXY="${PROXY_URL}" \
  --build-arg HTTPS_PROXY="${PROXY_URL}" \
  --build-arg all_proxy="${PROXY_URL}" \
  --build-arg ALL_PROXY="${PROXY_URL}" \
  --push \
  .

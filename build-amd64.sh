#!/bin/bash
set -euo pipefail

ARCH="$(uname -m)"

if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "amd64" ]; then
  echo "This script must be run on an amd64/x86_64 machine. Current architecture: $ARCH"
  exit 1
fi

docker build \
  --progress=plain \
  -f docker/Dockerfile \
  -t myuwhn/chatwoot:local \
  --build-arg NODE_OPTIONS="--max-old-space-size=8192 --openssl-legacy-provider" \
  .

docker push myuwhn/chatwoot:local

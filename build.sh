#!/bin/bash

docker buildx build --platform linux/amd64 -f docker/Dockerfile -t myuwhn/chatwoot:local --build-arg NODE_OPTIONS="--max-old-space-size=8192 --openssl-legacy-provider" --push .

docker push myuwhn/chatwoot:local

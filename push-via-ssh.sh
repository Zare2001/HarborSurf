#!/bin/bash
# Push a Docker image to Harbor without insecure-registries on your Mac (Colima).
# Builds locally, saves, pipes to server, load + push there.
#
# Usage:
#   ./push-via-ssh.sh [BUILD_CONTEXT]
#   REGISTRY_HOST=demo/myproject ./push-via-ssh.sh .
#
# Image ref must NOT include http:// — format: HOST/project/repo:tag

set -e

REGISTRY_HOST="${REGISTRY_HOST:-145.38.205.248}"
PROJECT="${HARBOR_PROJECT:-demo}"
REPO="${HARBOR_REPO:-myimage}"
TAG="${HARBOR_TAG:-latest}"
SSH_USER_HOST="${SSH_USER_HOST:-zpalanciya@${REGISTRY_HOST}}"
CONTEXT="${1:-.}"

IMAGE="${REGISTRY_HOST}/${PROJECT}/${REPO}:${TAG}"

echo "Building: $IMAGE"
docker build --platform linux/amd64 -t "$IMAGE" "$CONTEXT"

echo "Saving and pushing via SSH $SSH_USER_HOST ..."
docker save "$IMAGE" | ssh "$SSH_USER_HOST" "docker load && docker push \"$IMAGE\""

echo "Done: $IMAGE"

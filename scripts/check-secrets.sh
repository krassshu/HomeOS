#!/bin/sh
# Skan sekretów gitleaks: historia Git oraz bieżące drzewo robocze (pliki niescommitowane).
set -eu
cd "$(dirname "$0")/.."

# v8.30.1, index linux/amd64 + linux/arm64 (docker buildx imagetools inspect).
GITLEAKS_IMAGE="ghcr.io/gitleaks/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f"

run_gitleaks() {
  docker run --rm \
    -v "$PWD:/repo:ro" \
    -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0=/repo \
    "$GITLEAKS_IMAGE" "$@" --no-banner --redact --exit-code 1
}

echo "gitleaks: historia Git"
run_gitleaks git /repo

echo "gitleaks: drzewo robocze"
run_gitleaks dir /repo -c /repo/scripts/gitleaks-worktree.toml

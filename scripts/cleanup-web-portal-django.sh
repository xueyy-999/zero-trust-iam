#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
TARGET_DIR="$ROOT_DIR/services/web-portal-django"

if [ -d "$TARGET_DIR" ]; then
  rm -rf "$TARGET_DIR"
  echo "Removed $TARGET_DIR"
else
  echo "Not found: $TARGET_DIR"
fi


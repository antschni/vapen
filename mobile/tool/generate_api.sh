#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OPENAPI="$ROOT/api/openapi.yaml"
OUT="$ROOT/mobile/packages/vapen_api_gen"
if command -v openapi-generator-cli >/dev/null 2>&1; then
  rm -rf "$OUT"
  openapi-generator-cli generate \
    -i "$OPENAPI" \
    -g dart-dio \
    -o "$OUT" \
    --additional-properties=pubName=vapen_api_gen,serializationLibrary=json_serializable
  echo "Generated into $OUT"
else
  echo "openapi-generator-cli not found; using hand-maintained packages/vapen_api"
fi

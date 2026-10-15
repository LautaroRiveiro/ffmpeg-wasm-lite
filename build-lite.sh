#!/bin/bash
# Build de producción, single-thread. Equivale a `make prd` sin necesitar make.
# Deja ffmpeg-core.js / ffmpeg-core.wasm en packages/core/dist/{esm,umd}.
#
# Uso (Git Bash, con Docker Desktop corriendo):
#   ./build-lite.sh

set -euo pipefail
cd "$(dirname "$0")"

rm -rf ./packages/core/dist

docker buildx build \
  --progress=plain \
  --build-arg EXTRA_CFLAGS="-O3 -msimd128" \
  --build-arg EXTRA_LDFLAGS="" \
  --build-arg FFMPEG_ST=yes \
  --build-arg FFMPEG_MT="" \
  -o ./packages/core \
  .

ls -la ./packages/core/dist/esm

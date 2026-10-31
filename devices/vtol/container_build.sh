#!/bin/bash
# Construye la imagen del VTOL. Se ejecuta EN la Raspberry Pi (arm64).
#   devices/vtol/container_build.sh
# Requiere la base: images/build.sh noetic base
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"   # build context: raíz del repo

if ! docker image inspect muav/base:noetic > /dev/null 2>&1; then
    echo "[build] Falta muav/base:noetic. Construila primero: $ROOT/images/build.sh noetic base"
    exit 1
fi

docker build -t muav/vtol:noetic -f "$HERE/Dockerfile" "$ROOT"

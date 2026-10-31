#!/bin/bash
# Construye la imagen del dron PX4 ROS 2. Se ejecuta EN la companion (o en x86 para probar).
#   devices/px4_ros2/container_build.sh
# Requiere la base: images/build.sh jazzy base
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"   # build context: raíz del repo
DISTRO=jazzy                        # único perfil: ver Dockerfile

if ! docker image inspect "muav/base:$DISTRO" > /dev/null 2>&1; then
    echo "[build] Falta muav/base:$DISTRO. Construila primero: $ROOT/images/build.sh $DISTRO base"
    exit 1
fi

docker build -t "muav/px4_ros2:$DISTRO" --build-arg ROS_DISTRO="$DISTRO" -f "$HERE/Dockerfile" "$ROOT"

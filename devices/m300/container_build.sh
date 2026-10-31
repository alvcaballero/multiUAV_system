#!/bin/bash
# Construye la cadena del M300 por PSDK. Se ejecuta EN el Jetson (arm64, L4T r36.4).
#   devices/m300/container_build.sh [opencv|ros2|psdk|all]     (default: all)
# El perfil OSDK (Noetic vía jetson-containers) sigue en multiuav_bringup/devices/M300 hasta R2.
set -e

TARGET=${1:-all}
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"   # build context: raíz del repo (psdk lee images/msgs/humble.repos)

build_opencv() { docker build -t opencv-cuda:l4t-r36.4.0     -f "$HERE/Dockerfile.opencv" "$ROOT"; }
build_ros2()   { docker build -t ros-humble:l4t-r36.4.0      -f "$HERE/Dockerfile.ros2"   "$ROOT"; }
build_psdk()   { docker build -t ros-humble-psdk:l4t-r36.4.0 -f "$HERE/Dockerfile.psdk"   "$ROOT"; }

case "$TARGET" in
    opencv) build_opencv ;;
    ros2)   build_ros2 ;;
    psdk)   build_psdk ;;
    all)    build_opencv && build_ros2 && build_psdk ;;
    *) echo "Uso: $0 [opencv|ros2|psdk|all]"; exit 1 ;;
esac

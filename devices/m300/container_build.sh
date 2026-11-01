#!/bin/bash
# Construye las imágenes del M300. Se ejecuta EN el Jetson (arm64, L4T r36.4).
#   devices/m300/container_build.sh [opencv|ros2|psdk|ros1|osdk|all]     (default: all)
#     psdk: opencv → ros2 → psdk   (ROS 2 Humble)
#     osdk: opencv → ros1 → osdk   (ROS 1 Noetic desde fuentes)
# Cada objetivo construye SOLO esa imagen: si su base no existe, construila antes (o usá all).
set -e

TARGET=${1:-all}
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"   # build context: raíz del repo (leen images/msgs/*.repos y devices/m300/*/*.repos)

build() { docker build -t "$1" -f "$HERE/$2" "$ROOT"; }

build_opencv() { build opencv-cuda:l4t-r36.4.0     base/Dockerfile.opencv; }
build_ros2()   { build ros-humble:l4t-r36.4.0      psdk/Dockerfile.ros2; }
build_psdk()   { build ros-humble-psdk:l4t-r36.4.0 psdk/Dockerfile; }
build_ros1()   { build ros-noetic:l4t-r36.4.0      osdk/Dockerfile.ros1; }
build_osdk()   { build ros-noetic-osdk:l4t-r36.4.0 osdk/Dockerfile; }

case "$TARGET" in
    opencv) build_opencv ;;
    ros2)   build_ros2 ;;
    psdk)   build_psdk ;;
    ros1)   build_ros1 ;;
    osdk)   build_osdk ;;
    all)    build_opencv && build_ros2 && build_psdk && build_ros1 && build_osdk ;;
    *) echo "Uso: $0 [opencv|ros2|psdk|ros1|osdk|all]"; exit 1 ;;
esac

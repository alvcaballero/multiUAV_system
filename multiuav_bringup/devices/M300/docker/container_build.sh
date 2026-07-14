#!/bin/bash
# Usage: ./container_build.sh [osdk|psdk|all]
# Default: all

set -e

TARGET=${1:-all}

build_opencv() {
    echo "[build] Building OpenCV CUDA base..."
    docker build -t opencv-cuda:l4t-r36.4.0 -f Dockerfile.opencv .
    echo "[build] OpenCV CUDA base done."
}

build_osdk() {
    echo "[build] Building OSDK stack (ROS Noetic)..."
    docker build -t ros-noetic:l4t-r36.4.0 -f Dockerfile.ros1 .
    docker build -t ros-noetic-osdk:l4t-r36.4.0 -f Dockerfile.osdk .
    echo "[build] OSDK stack done."
}

build_psdk() {
    echo "[build] Building PSDK stack (ROS Humble)..."
    docker build -t ros-humble:l4t-r36.4.0 -f Dockerfile.ros2 .
    docker build -t ros-humble-psdk:l4t-r36.4.0 -f Dockerfile.psdk .
    echo "[build] PSDK stack done."
}

case "$TARGET" in
    opencv) build_opencv ;;
    osdk)   build_opencv && build_osdk ;;
    psdk)   build_opencv && build_psdk ;;
    all)    build_opencv && build_osdk && build_psdk ;;
    *)
        echo "Usage: $0 [osdk|psdk|all]"
        exit 1
        ;;
esac

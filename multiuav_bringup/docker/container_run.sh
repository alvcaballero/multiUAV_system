#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

CONTAINER_NAME="px4_noetic"
IMAGE_NAME="muavgcs:noetic"

PROJECT_DIR="${HOME}/work/ros_docker_volume"
PROJECT_DIST="/app"

# Configuración X11 para acceso gráfico
xhost +local:docker

# --- Detección de GPU NVIDIA ---
echo "Checking for NVIDIA GPU..."
HAS_NVIDIA_GPU=false
if command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null; then
        HAS_NVIDIA_GPU=true
        echo "NVIDIA GPU detected. Using GPU-enabled Docker run."
    fi
fi

# Detect if WSL or Linux
IS_WSL=$(grep -i "microsoft" /proc/version)

# --- Comprobar si el contenedor ya existe o está en ejecución ---
if [ "$(docker ps -qaf name=$CONTAINER_NAME)" = "" ]; then
    echo 'Container not found, creating it ...'

    if [ -n "$IS_WSL" ]; then
        export DISPLAY=:0
        XAUTHORITY=/mnt/wslg/.Xauthority
    fi

    DOCKER_RUN_COMMON=(
        -it
        --name $CONTAINER_NAME
        --privileged
        --workdir $PROJECT_DIST
        --env DISPLAY=$DISPLAY
        --network host
        --ipc=host
        --volume /tmp/.X11-unix:/tmp/.X11-unix:rw
        --mount type=bind,source=$PROJECT_DIR,destination=$PROJECT_DIST
    )

    if [ -n "$IS_WSL" ]; then
        DOCKER_RUN_COMMON+=(--volume /mnt/wslg:/mnt/wslg)
    fi

    XDG_RUNTIME_DIR=/tmp/runtime-root
    mkdir -p $XDG_RUNTIME_DIR
    chmod 0700 $XDG_RUNTIME_DIR

    DOCKER_RUN_GPU=(
        --env XAUTHORITY=$XAUTHORITY
        --volume $XAUTHORITY:$XAUTHORITY
        --env QT_X11_NO_MITSHM=1
        --env NVIDIA_VISIBLE_DEVICES=all
        --env NVIDIA_DRIVER_CAPABILITIES=all
        --env XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR
        --env __NV_PRIME_RENDER_OFFLOAD=1
        --env __GLX_VENDOR_LIBRARY_NAME=nvidia
        --device /dev/dri:/dev/dri
        --volume /etc/machine-id:/etc/machine-id:ro
        --gpus all
    )

    if $HAS_NVIDIA_GPU; then
        docker run "${DOCKER_RUN_COMMON[@]}" "${DOCKER_RUN_GPU[@]}" "$IMAGE_NAME" bash
    else
        docker run "${DOCKER_RUN_COMMON[@]}" "$IMAGE_NAME" bash
    fi
    echo 'Container created.'
else
    if [ "${1}" = "restart" ] && ! docker stop $CONTAINER_NAME > /dev/null; then
        echo 'Error while stopping the container, exiting now ...'
        return 1
    fi
    if ! docker start $CONTAINER_NAME > /dev/null; then
        echo 'Error while starting the container, exiting now ...'
        return 1
    fi
    echo 'Container found and running, executing a shell ...'
    docker exec -it $CONTAINER_NAME bash --login
fi

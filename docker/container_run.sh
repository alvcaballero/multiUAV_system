#!/bin/bash
# container_run.sh — crea o reanuda el contenedor ROS
#
# Uso:
#   ./container_run.sh              → imagen gcs (default, liviana ~4 GB)
#   ./container_run.sh sim          → imagen sim (completa con PX4/Gazebo ~9 GB)
#   ./container_run.sh restart      → detiene y reanuda el contenedor activo
#
# Primera vez: después de crear el contenedor, poblar el volumen con:
#   docker exec -it <container> bash /app/initDev.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ── Selección de perfil ────────────────────────────────────────────────────────
PROFILE="${1:-gcs}"

case "$PROFILE" in
    gcs)
        CONTAINER_NAME="muavgcs_ros1_gcs"
        IMAGE_NAME="muavgcs:ros1-gcs"
        ;;
    sim)
        CONTAINER_NAME="muavgcs_ros1_sim"
        IMAGE_NAME="muavgcs:ros1-sim"
        ;;
    restart)
        # restart usa el contenedor que exista — detectar cual está activo
        PROFILE="gcs"
        CONTAINER_NAME="muavgcs_ros1_gcs"
        IMAGE_NAME="muavgcs:ros1-gcs"
        ;;
    *)
        echo "Uso: $0 [gcs|sim|restart]"
        exit 1
        ;;
esac

PROJECT_DIR="${HOME}/work/ros_docker_volume"
PROJECT_DIST="/app"

# ── X11 ───────────────────────────────────────────────────────────────────────
xhost +local:docker

# ── GPU NVIDIA ────────────────────────────────────────────────────────────────
echo "Checking for NVIDIA GPU..."
HAS_NVIDIA_GPU=false
if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
    HAS_NVIDIA_GPU=true
    echo "NVIDIA GPU detected."
fi

# ── WSL ───────────────────────────────────────────────────────────────────────
IS_WSL=$(grep -i "microsoft" /proc/version 2>/dev/null || true)

# ── Crear o reanudar ──────────────────────────────────────────────────────────
if [ "$(docker ps -qaf name=^${CONTAINER_NAME}$)" = "" ]; then
    echo "Container not found, creating $CONTAINER_NAME ($IMAGE_NAME)..."

    if [ -n "$IS_WSL" ]; then
        export DISPLAY=:0
        XAUTHORITY=/mnt/wslg/.Xauthority
    fi

    XDG_RUNTIME_DIR=/tmp/runtime-root
    mkdir -p $XDG_RUNTIME_DIR
    chmod 0700 $XDG_RUNTIME_DIR

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

    DOCKER_RUN_GPU=(
        --env XAUTHORITY=${XAUTHORITY:-}
        --volume ${XAUTHORITY:-/dev/null}:${XAUTHORITY:-/dev/null}
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

    echo "Container $CONTAINER_NAME created."
    echo ""
    echo "Si es la primera vez, pobla el volumen dentro del contenedor:"
    echo "  docker exec -it $CONTAINER_NAME bash /app/initDev.sh"

else
    if [ "${1}" = "restart" ]; then
        docker stop $CONTAINER_NAME > /dev/null || { echo "Error stopping container."; exit 1; }
    fi
    docker start $CONTAINER_NAME > /dev/null || { echo "Error starting container."; exit 1; }
    echo "Container $CONTAINER_NAME running."
    docker exec -it $CONTAINER_NAME bash --login
fi

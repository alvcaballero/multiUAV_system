#!/bin/bash
# Arranca un contenedor del sistema.
#   ./container_run.sh dev <distro> [restart]     desarrollo: monta ws/<distro> en /ws
#   ./container_run.sh bridge <distro>            rosbridge del GCS (primer plano, --rm)
#       noetic: MUAV_HOSTS=<gcs>,<dron1>,... ./container_run.sh bridge noetic   (multimaster)
#   ./container_run.sh <dispositivo> [args...]    delega en devices/<dispositivo>/container_run.sh
# Las imágenes salen de images/build.sh <distro>.
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET=${1:?Uso: $0 <dev|bridge> <distro> [restart] | $0 <dispositivo> [args...]}
shift

# ── Dispositivos: cada uno sabe cómo arrancarse (hardware, credenciales, puertos) ─────────────────
if [ "$TARGET" != dev ] && [ "$TARGET" != bridge ]; then
    DEVICE_RUN="$ROOT/devices/$TARGET/container_run.sh"
    if [ ! -x "$DEVICE_RUN" ]; then
        echo "No existe $DEVICE_RUN"
        exit 1
    fi
    exec "$DEVICE_RUN" "$@"
fi

DISTRO=${1:?Falta la distro: humble | jazzy | noetic}
ACTION=${2:-}
IMAGE="muav/$TARGET:$DISTRO"

if [ "$TARGET" = bridge ]; then
    # --env VAR sin valor: pasa la del host solo si está definida. MUAV_HOSTS: hosts del multimaster (noetic).
    exec docker run --rm -it --name "muav_bridge_$DISTRO" --network host \
        --env MUAV_HOSTS --env ROS_MASTER_URI --env ROS_HOSTNAME --env ROS_IP --env ROS_DOMAIN_ID \
        "$IMAGE"
fi

# ── dev ─────────────────────────────────────────────────────────────────────────────────────────
CONTAINER_NAME="muav_dev_$DISTRO"
WS_DIR="$ROOT/ws/$DISTRO"
mkdir -p "$WS_DIR/src"

if [ -n "$(docker ps -qaf name="^${CONTAINER_NAME}$")" ]; then
    if [ "$ACTION" = restart ]; then
        docker rm -f "$CONTAINER_NAME" > /dev/null
    else
        docker start "$CONTAINER_NAME" > /dev/null
        exec docker exec -it "$CONTAINER_NAME" bash
    fi
fi

xhost +local:docker > /dev/null 2>&1 || true

DOCKER_ARGS=(
    -it
    --name "$CONTAINER_NAME"
    --privileged
    --network host
    --ipc host
    --env DISPLAY="$DISPLAY"
    --env QT_X11_NO_MITSHM=1
    --volume /tmp/.X11-unix:/tmp/.X11-unix:rw
    --volume "$WS_DIR":/ws
)

# WSL: el servidor X vive en /mnt/wslg
if grep -qi microsoft /proc/version; then
    DOCKER_ARGS+=(--volume /mnt/wslg:/mnt/wslg)
fi

if command -v nvidia-smi > /dev/null 2>&1 && nvidia-smi > /dev/null 2>&1; then
    echo "[run] GPU NVIDIA detectada"
    DOCKER_ARGS+=(
        --gpus all
        --env NVIDIA_VISIBLE_DEVICES=all
        --env NVIDIA_DRIVER_CAPABILITIES=all
        --env __NV_PRIME_RENDER_OFFLOAD=1
        --env __GLX_VENDOR_LIBRARY_NAME=nvidia
        --device /dev/dri:/dev/dri
    )
fi

echo "[run] $IMAGE  ws: $WS_DIR → /ws"
exec docker run "${DOCKER_ARGS[@]}" "$IMAGE" bash

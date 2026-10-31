#!/bin/bash
# Arranca (o entra en) el contenedor del M210. Se ejecuta EN la Raspberry Pi.
#   MUAV_HOSTS=<gcs> devices/m210/container_run.sh [restart]
# MUAV_HOSTS: el/los GCS para el multimaster.
# La config real (credenciales DJI) vive en devices/m210/cfg/ (gitignored) y se monta en /root/cfg.
# Para desarrollar a bordo: M210_DEV_SRC=<dir> monta ese dir en /root/app_ws/src/external.
set -e

ACTION=
for arg in "$@"; do
    case "$arg" in
        restart) ACTION=restart ;;
        *) echo "Argumento desconocido: $arg"; echo "Uso: $0 [restart]"; exit 1 ;;
    esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
CFG_DIR="$HERE/cfg"
CONTAINER_NAME="m210_osdk"
IMAGE="muav/m210:noetic"
WS="/root/app_ws"

if [ ! -f "$CFG_DIR/UserConfig_osdk.txt" ]; then
    echo "[run] ERROR: falta $CFG_DIR/UserConfig_osdk.txt"
    echo "  cp $CFG_DIR/UserConfig_osdk.txt.example $CFG_DIR/UserConfig_osdk.txt   # y completar"
    exit 1
fi
if [ ! -c /dev/ttyUSB0 ] && [ ! -c /dev/ttyACM0 ]; then
    echo "[run] WARN: ni /dev/ttyUSB0 ni /dev/ttyACM0: verificá la conexión con el M210."
fi
if [ -z "$MUAV_HOSTS" ]; then
    echo "[run] WARN: MUAV_HOSTS vacío: el multimaster del dron no va a ver ningún GCS."
fi

DOCKER_ARGS=(
    --name "$CONTAINER_NAME"
    --privileged
    --network host
    --env MUAV_HOSTS
    -v "$CFG_DIR":/root/cfg:ro
    -v /dev/bus/usb:/dev/bus/usb
    # ros_rtsp lee $(find ros_rtsp)/config/stream_setup.yaml sin argumento para cambiarla: se monta encima.
    -v "$HERE/config/ros_rtsp_stream_setup.yaml":"$WS/src/ros_rtsp/config/stream_setup.yaml":ro
)
[ -c /dev/ttyUSB0 ] && DOCKER_ARGS+=(--device=/dev/ttyUSB0:/dev/ttyUSB0)
[ -c /dev/ttyACM0 ] && DOCKER_ARGS+=(--device=/dev/ttyACM0:/dev/ttyACM0)
if [ -n "$M210_DEV_SRC" ]; then
    DOCKER_ARGS+=(-v "$M210_DEV_SRC":"$WS/src/external")
fi

if [ -n "$(docker ps -qaf name="^${CONTAINER_NAME}$")" ]; then
    if [ "$ACTION" = restart ]; then
        docker rm -f "$CONTAINER_NAME" > /dev/null
    else
        docker start "$CONTAINER_NAME" > /dev/null
        exec docker exec -it "$CONTAINER_NAME" bash --login
    fi
fi

echo "[run] $IMAGE → $CONTAINER_NAME"
exec docker run -it "${DOCKER_ARGS[@]}" "$IMAGE" bash

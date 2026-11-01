#!/bin/bash
# Arranca (o entra en) el contenedor del M300. Se ejecuta EN el Jetson.
#   devices/m300/container_run.sh <psdk|osdk> [restart] [--no-bulk]
#     psdk          ROS 2 Humble. UART + USB bulk (vídeo de alta velocidad vía functionfs)
#     psdk --no-bulk  solo UART, sin endpoints bulk
#     osdk          ROS 1 Noetic. UART + ACM (MUAV_HOSTS = el/los GCS, para el multimaster)
# PSDK y OSDK son excluyentes: el gadget USB del Jetson está en un modo u otro (host/set_usb_mode.sh).
# Guías de conexión y puesta en marcha: psdk/SETUP.md, osdk/SETUP.md.
# La config real (credenciales DJI) vive en devices/m300/cfg/ (gitignored) y se monta en /root/cfg.
# Para desarrollar a bordo: M300_DEV_SRC=<dir> monta ese dir en <workspace>/src/external.
set -e

SDK=${1:-}
case "$SDK" in
    psdk|osdk) shift ;;
    *) echo "Uso: $0 <psdk|osdk> [restart] [--no-bulk]"; exit 1 ;;
esac

ACTION=
NO_BULK=0
for arg in "$@"; do
    case "$arg" in
        --no-bulk) NO_BULK=1 ;;
        restart)   ACTION=restart ;;
        *) echo "Argumento desconocido: $arg"; echo "Uso: $0 <psdk|osdk> [restart] [--no-bulk]"; exit 1 ;;
    esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
CFG_DIR="$HERE/cfg"

case "$SDK" in
    psdk)
        CONTAINER_NAME="m300_psdk"
        IMAGE="ros-humble-psdk:l4t-r36.4.0"
        WS="/root/psdk_ws"
        CFG_FILES=(psdk_params.yaml link_config.json)
        ;;
    osdk)
        CONTAINER_NAME="m300_osdk"
        IMAGE="ros-noetic-osdk:l4t-r36.4.0"
        WS="/root/app_ws"
        CFG_FILES=(UserConfig_osdk.txt)
        ;;
esac

for f in "${CFG_FILES[@]}"; do
    if [ ! -f "$CFG_DIR/$f" ]; then
        echo "[run] ERROR: falta $CFG_DIR/$f"
        echo "  cp $CFG_DIR/$f.example $CFG_DIR/$f   # y completar"
        exit 1
    fi
done

check_bulk_endpoints() {
    local missing=0
    for ep in bulk1 bulk2; do
        if [ ! -d "/dev/usb-ffs/$ep" ]; then
            echo "[run] ERROR: /dev/usb-ffs/$ep no existe en el host."
            missing=1
        fi
    done
    if [ "$missing" -eq 1 ]; then
        echo "  Ejecutá primero en el host: sudo $HERE/host/set_usb_mode.sh psdk --now"
        exit 1
    fi
    if ! pgrep -x startup_bulk > /dev/null 2>&1; then
        echo "[run] WARN: startup_bulk no está corriendo: los endpoints bulk pueden no estar activos."
    fi
}

if [ ! -c /dev/ttyUSB0 ] && [ ! -c /dev/ttyACM0 ]; then
    echo "[run] WARN: ni /dev/ttyUSB0 ni /dev/ttyACM0: verificá la conexión UART."
fi
if [ "$SDK" = psdk ]; then
    if [ "$NO_BULK" -eq 0 ]; then
        check_bulk_endpoints
    else
        echo "[run] WARN: --no-bulk: solo UART, sin streaming de vídeo de alta velocidad."
    fi
elif [ -z "$MUAV_HOSTS" ]; then
    echo "[run] WARN: MUAV_HOSTS vacío: el multimaster del dron no va a ver ningún GCS."
fi

DOCKER_ARGS=(
    --name "$CONTAINER_NAME"
    --privileged
    --runtime nvidia
    --network host
    --env DISPLAY="$DISPLAY"
    --env NVIDIA_DRIVER_CAPABILITIES=all
    --env MUAV_HOSTS
    -v /tmp/.X11-unix:/tmp/.X11-unix
    -v "$CFG_DIR":/root/cfg:ro
    -v /dev/bus/usb:/dev/bus/usb
)
[ -c /dev/ttyUSB0 ] && DOCKER_ARGS+=(--device=/dev/ttyUSB0:/dev/ttyUSB0)
[ -c /dev/ttyACM0 ] && DOCKER_ARGS+=(--device=/dev/ttyACM0:/dev/ttyACM0)
if [ "$SDK" = psdk ] && [ "$NO_BULK" -eq 0 ]; then
    # functionfs: son filesystems virtuales, van como bind mount, no como --device
    DOCKER_ARGS+=(-v /dev/usb-ffs/bulk1:/dev/usb-ffs/bulk1 -v /dev/usb-ffs/bulk2:/dev/usb-ffs/bulk2)
fi
if [ "$SDK" = osdk ]; then
    # ros_rtsp lee $(find ros_rtsp)/config/stream_setup.yaml sin argumento para cambiarla: se monta encima.
    DOCKER_ARGS+=(-v "$HERE/osdk/ros_rtsp_stream_setup.yaml":"$WS/src/ros_rtsp/config/stream_setup.yaml":ro)
fi
if [ -n "$M300_DEV_SRC" ]; then
    DOCKER_ARGS+=(-v "$M300_DEV_SRC":"$WS/src/external")
fi

xhost +local:docker > /dev/null 2>&1 || true

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

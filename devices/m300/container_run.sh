#!/bin/bash
# Arranca (o entra en) el contenedor PSDK del M300. Se ejecuta EN el Jetson.
#   devices/m300/container_run.sh [restart] [--no-bulk]
#     (sin flags)  UART + USB bulk (vídeo de alta velocidad vía functionfs)
#     --no-bulk    solo UART, sin endpoints bulk
# La config real (credenciales DJI) vive en devices/m300/cfg/ (gitignored) y se monta en /root/cfg.
# Para desarrollar a bordo: M300_DEV_SRC=<dir> monta ese dir en /root/psdk_ws/src/external.
set -e

ACTION=
NO_BULK=0
for arg in "$@"; do
    case "$arg" in
        --no-bulk) NO_BULK=1 ;;
        restart)   ACTION=restart ;;
        *) echo "Argumento desconocido: $arg"; echo "Uso: $0 [restart] [--no-bulk]"; exit 1 ;;
    esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
CFG_DIR="$HERE/cfg"
CONTAINER_NAME="m300_psdk"
IMAGE="ros-humble-psdk:l4t-r36.4.0"

for f in psdk_params.yaml link_config.json; do
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
    if [ ! -c /dev/ttyUSB0 ] && [ ! -c /dev/ttyACM0 ]; then
        echo "[run] WARN: ni /dev/ttyUSB0 ni /dev/ttyACM0: verificá la conexión UART."
    fi
    if [ "$missing" -eq 1 ]; then
        echo "  Ejecutá primero en el host: sudo $HERE/set_usb_mode.sh psdk --now"
        exit 1
    fi
    if ! pgrep -x startup_bulk > /dev/null 2>&1; then
        echo "[run] WARN: startup_bulk no está corriendo: los endpoints bulk pueden no estar activos."
    fi
}

if [ "$NO_BULK" -eq 0 ]; then
    check_bulk_endpoints
else
    echo "[run] WARN: --no-bulk: solo UART, sin streaming de vídeo de alta velocidad."
fi

DOCKER_ARGS=(
    --name "$CONTAINER_NAME"
    --privileged
    --runtime nvidia
    --network host
    --env DISPLAY="$DISPLAY"
    --env NVIDIA_DRIVER_CAPABILITIES=all
    -v /tmp/.X11-unix:/tmp/.X11-unix
    -v "$CFG_DIR":/root/cfg:ro
    -v /dev/bus/usb:/dev/bus/usb
)
[ -c /dev/ttyUSB0 ] && DOCKER_ARGS+=(--device=/dev/ttyUSB0:/dev/ttyUSB0)
[ -c /dev/ttyACM0 ] && DOCKER_ARGS+=(--device=/dev/ttyACM0:/dev/ttyACM0)
if [ "$NO_BULK" -eq 0 ]; then
    # functionfs: son filesystems virtuales, van como bind mount, no como --device
    DOCKER_ARGS+=(-v /dev/usb-ffs/bulk1:/dev/usb-ffs/bulk1 -v /dev/usb-ffs/bulk2:/dev/usb-ffs/bulk2)
fi
if [ -n "$M300_DEV_SRC" ]; then
    DOCKER_ARGS+=(-v "$M300_DEV_SRC":/root/psdk_ws/src/external)
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

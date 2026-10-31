#!/bin/bash
# Arranca (o entra en) el contenedor del VTOL. Se ejecuta EN la Raspberry Pi.
#   MUAV_HOSTS=<gcs> devices/vtol/container_run.sh [restart]
# MUAV_HOSTS: el/los GCS para el multimaster.
# Pasa el autopiloto (/dev/ttyUSB0, lo abre mavros en atlas.launch) y TODAS las /dev/video* (la cámara cambia de número).
# Para desarrollar a bordo: VTOL_DEV_SRC=<dir> monta ese dir en /root/app_ws/src/external.
set -e

ACTION=
for arg in "$@"; do
    case "$arg" in
        restart) ACTION=restart ;;
        *) echo "Argumento desconocido: $arg"; echo "Uso: $0 [restart]"; exit 1 ;;
    esac
done

CONTAINER_NAME="vtol"
IMAGE="muav/vtol:noetic"
WS="/root/app_ws"

if [ ! -c /dev/ttyUSB0 ]; then
    echo "[run] WARN: no existe /dev/ttyUSB0: mavros no va a ver el autopiloto (atlas.launch usa serial:///dev/ttyUSB0:57600)."
fi
if [ -z "$MUAV_HOSTS" ]; then
    echo "[run] WARN: MUAV_HOSTS vacío: el multimaster del dron no va a ver ningún GCS."
fi

DOCKER_ARGS=(
    --name "$CONTAINER_NAME"
    --privileged
    --network host
    --env MUAV_HOSTS
)
[ -c /dev/ttyUSB0 ] && DOCKER_ARGS+=(--device=/dev/ttyUSB0:/dev/ttyUSB0)
for v in /dev/video*; do
    [ -c "$v" ] && DOCKER_ARGS+=(--device="$v:$v")
done
if [ -n "$VTOL_DEV_SRC" ]; then
    DOCKER_ARGS+=(-v "$VTOL_DEV_SRC":"$WS/src/external")
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

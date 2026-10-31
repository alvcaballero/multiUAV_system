#!/bin/bash
# Arranca (o entra en) el contenedor del dron PX4 ROS 2. Se ejecuta EN la companion.
#   devices/px4_ros2/container_run.sh [restart]
# Pasa los puertos serie que existan (ttyUSB*, ttyACM*, ttyTHS*: el Agent abre el del autopiloto) y ROS_DOMAIN_ID.
# Para desarrollar a bordo: PX4_ROS2_DEV_SRC=<dir> monta ese dir en /root/app_ws/src/external.
set -e

ACTION=
for arg in "$@"; do
    case "$arg" in
        restart) ACTION=restart ;;
        *) echo "Argumento desconocido: $arg"; echo "Uso: $0 [restart]"; exit 1 ;;
    esac
done

CONTAINER_NAME="px4_ros2"
IMAGE="muav/px4_ros2:jazzy"
WS="/root/app_ws"

# --ipc host: Fast-DDS usa memoria compartida entre procesos del MISMO host; en contenedores con IPC separado
# se descubren pero no reciben datos.
DOCKER_ARGS=(
    --name "$CONTAINER_NAME"
    --privileged
    --network host
    --ipc host
    --env ROS_DOMAIN_ID
)
SERIALS=()
for d in /dev/ttyUSB* /dev/ttyACM* /dev/ttyTHS*; do
    [ -c "$d" ] && DOCKER_ARGS+=(--device="$d:$d") && SERIALS+=("$d")
done
if [ ${#SERIALS[@]} -eq 0 ]; then
    echo "[run] WARN: ningún puerto serie: el Agent no va a ver el autopiloto (salvo por UDP)."
fi
if [ -n "$PX4_ROS2_DEV_SRC" ]; then
    DOCKER_ARGS+=(-v "$PX4_ROS2_DEV_SRC":"$WS/src/external")
fi

if [ -n "$(docker ps -qaf name="^${CONTAINER_NAME}$")" ]; then
    if [ "$ACTION" = restart ]; then
        docker rm -f "$CONTAINER_NAME" > /dev/null
    else
        docker start "$CONTAINER_NAME" > /dev/null
        exec docker exec -it "$CONTAINER_NAME" bash --login
    fi
fi

echo "[run] $IMAGE → $CONTAINER_NAME  serie: ${SERIALS[*]:-ninguno}"
exec docker run -it "${DOCKER_ARGS[@]}" "$IMAGE" bash

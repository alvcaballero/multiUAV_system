#!/bin/bash
# Arranca un contenedor del sistema.
#   ./container_run.sh dev <distro> [restart]     desarrollo: monta el workspace en /ws (ver "dev" abajo)
#       MUAV_WS_<DISTRO>=<dir>: otro workspace DEL CONTENEDOR (ej. MUAV_WS_HUMBLE=~/ws_psdk); sin ella, ws/<distro>.
#       Nunca uno compilado en el host (ej. ~/ros2_px4_ws): sus rutas absolutas se rompen en /ws y colcon lo pisa.
#       Si el devcontainer de VS Code (muav_devcontainer_<distro>) está corriendo, entra en ESE: un solo entorno.
#   ./container_run.sh bridge <distro>            rosbridge del GCS (primer plano, --rm)
#       noetic: MUAV_HOSTS=<dron1>,<dron2>,... ./container_run.sh bridge noetic   (multimaster)
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
    # --ipc host: Fast-DDS usa memoria compartida con los procesos del MISMO host (dev, un dron simulado); con IPC
    # separado se descubren pero no reciben datos.
    exec docker run --rm -it --name "muav_bridge_$DISTRO" --network host --ipc host \
        --env MUAV_HOSTS --env ROS_MASTER_URI --env ROS_HOSTNAME --env ROS_IP --env ROS_DOMAIN_ID \
        "$IMAGE"
fi

# ── dev ─────────────────────────────────────────────────────────────────────────────────────────
# El workspace entero (src, build, install, log) vive en el HOST y se monta SIEMPRE en /ws: install/ guarda rutas
# absolutas, así que la terminal y el devcontainer comparten compilación solo si los dos lo ven en /ws.
CONTAINER_NAME="muav_dev_$DISTRO"
DEVCONTAINER_NAME="muav_devcontainer_$DISTRO"   # .devcontainer/<distro>*/devcontainer.json
WS_VAR="MUAV_WS_${DISTRO^^}"
WS_DIR="${!WS_VAR:-$ROOT/ws/$DISTRO}"
WS_DIR="${WS_DIR/#\~/$HOME}"
mkdir -p "$WS_DIR/src"
WS_DIR="$(cd "$WS_DIR" && pwd -P)"

source "$ROOT/images/dev/ws_guard.sh"
ELSEWHERE=$(muav_ws_built_elsewhere "$WS_DIR")
if [ -n "$ELSEWHERE" ]; then
    echo "[run] ERROR: $WS_DIR está compilado FUERA del contenedor ($ELSEWHERE): es un entorno local." >&2
    echo "[run]   Montarlo rompe sus rutas absolutas y un colcon build dentro pisa el del host." >&2
    echo "[run]   Usá un workspace propio del contenedor: unset $WS_VAR (→ ws/$DISTRO) o apuntala a otro directorio." >&2
    exit 1
fi

# Qué monta en /ws un contenedor existente. Entrar en uno con OTRO workspace compila donde no creés, sin error.
check_ws() {
    local mounted
    mounted=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/ws"}}{{.Source}}{{end}}{{end}}' "$1")
    [ -d "$mounted" ] && mounted="$(cd "$mounted" && pwd -P)"   # misma forma que WS_DIR (sin symlinks)
    if [ "$mounted" != "$WS_DIR" ]; then
        echo "[run] ERROR: $1 monta '$mounted' en /ws, y pediste '$WS_DIR' ($WS_VAR)." >&2
        echo "[run]   $2" >&2
        exit 1
    fi
}

if [ "$ACTION" != restart ] && [ -n "$(docker ps -qf name="^${DEVCONTAINER_NAME}$")" ]; then
    check_ws "$DEVCONTAINER_NAME" "Cerrá VS Code o usá el mismo $WS_VAR que él."
    echo "[run] devcontainer de VS Code en marcha: $DEVCONTAINER_NAME"
    exec docker exec -it "$DEVCONTAINER_NAME" bash
fi

if [ -n "$(docker ps -qaf name="^${CONTAINER_NAME}$")" ]; then
    if [ "$ACTION" = restart ]; then
        docker rm -f "$CONTAINER_NAME" > /dev/null
    else
        check_ws "$CONTAINER_NAME" "Recrealo con: $0 dev $DISTRO restart"
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
    --env ROS_DOMAIN_ID
    --volume /tmp/.X11-unix:/tmp/.X11-unix:rw
    --volume /etc/machine-id:/etc/machine-id:ro
    --volume "$WS_DIR":/ws
)

# Con xhost +local:docker alcanza; XAUTHORITY por si el servidor X exige cookie (Wayland/XWayland lo hace a veces).
if [ -n "$XAUTHORITY" ] && [ -f "$XAUTHORITY" ]; then
    DOCKER_ARGS+=(--env XAUTHORITY="$XAUTHORITY" --volume "$XAUTHORITY":"$XAUTHORITY":ro)
fi

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

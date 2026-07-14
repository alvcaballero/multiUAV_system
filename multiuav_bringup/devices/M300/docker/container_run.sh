#!/bin/bash
# Usage: ./container_run.sh [osdk|psdk] [restart|--no-bulk]
#   psdk            → con USB bulk (video de alta velocidad vía functionfs)
#   psdk --no-bulk  → solo UART, sin bulk endpoints (modo OSDK-like)
# Default: osdk

set -e

SDK=${1:-osdk}
ACTION=
NO_BULK=0

# Parsear flags restantes (orden libre)
shift
for arg in "$@"; do
    case "$arg" in
        --no-bulk) NO_BULK=1 ;;
        restart)   ACTION=restart ;;
        *) echo "Argumento desconocido: $arg"; exit 1 ;;
    esac
done

xhost +local:docker > /dev/null 2>&1 || true

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Configuración por SDK ─────────────────────────────────────────────────────

case "$SDK" in
    osdk)
        CONTAINER_NAME="m300_osdk"
        IMAGE="ros-noetic-osdk:l4t-r36.4.0"
        PROJECT_DIR="${HOME}/app_ros1"
        PROJECT_DIST="/root/app_ws/src/external"
        USER_CONFIG_HOST="$SCRIPT_DIR/UserConfig_osdk.txt"
        USER_CONFIG_CONTAINER="/root/Onboard-SDK/build/bin/UserConfig_osdk.txt"
        ;;
    psdk)
        CONTAINER_NAME="m300_psdk"
        IMAGE="ros-humble-psdk:l4t-r36.4.0"
        PROJECT_DIR="${HOME}/app_ros2"
        PROJECT_DIST="/root/psdk_ws/src/external"
        USER_CONFIG_HOST="$SCRIPT_DIR/UserConfig_psdk.txt"
        USER_CONFIG_CONTAINER="/root/UserConfig_psdk.txt"
        ;;
    *)
        echo "Usage: $0 [osdk|psdk] [restart] [--no-bulk]"
        exit 1
        ;;
esac

mkdir -p "$PROJECT_DIR"

echo "[run] SDK:       $SDK"
echo "[run] Image:     $IMAGE"
echo "[run] Container: $CONTAINER_NAME"

# ── Verificaciones previas para PSDK ─────────────────────────────────────────

check_psdk_host_setup() {
    local MISSING=0

    if [ ! -d /dev/usb-ffs/bulk1 ]; then
        echo "[run] ERROR: /dev/usb-ffs/bulk1 no existe en el host."
        MISSING=1
    fi
    if [ ! -d /dev/usb-ffs/bulk2 ]; then
        echo "[run] ERROR: /dev/usb-ffs/bulk2 no existe en el host."
        MISSING=1
    fi
    if [ ! -c /dev/ttyUSB0 ] && [ ! -c /dev/ttyACM0 ]; then
        echo "[run] WARN: ni /dev/ttyUSB0 ni /dev/ttyACM0 encontrados — verificá la conexión UART."
    fi

    if [ "$MISSING" -eq 1 ]; then
        echo ""
        echo "  El host no tiene los USB bulk endpoints listos."
        echo "  Ejecutá primero en el host (como root):"
        echo "    sudo ./set_usb_mode.sh psdk --now"
        echo ""
        exit 1
    fi

    # Verificar que startup_bulk esté corriendo
    if ! pgrep -x startup_bulk > /dev/null 2>&1; then
        echo "[run] WARN: startup_bulk no está corriendo. Los endpoints bulk pueden no estar activos."
        echo "  Inicialo manualmente: sudo /ruta/a/startup_bulk /dev/usb-ffs/bulk1 &"
    fi
}

# ── Construcción del comando docker run ──────────────────────────────────────

build_docker_run_args() {
    DOCKER_ARGS=(
        --name "$CONTAINER_NAME"
        --privileged
        --runtime nvidia
        --network host
        --workdir "$PROJECT_DIST"
        --env DISPLAY="$DISPLAY"
        --env NVIDIA_DRIVER_CAPABILITIES=all
        -v /tmp/.X11-unix:/tmp/.X11-unix
        -v "$PROJECT_DIR":"$PROJECT_DIST"
        -v "$USER_CONFIG_HOST":"$USER_CONFIG_CONTAINER":ro
        -v /dev/bus/usb:/dev/bus/usb
    )

    # UART — añadir solo los que existan en el host
    [ -c /dev/ttyUSB0 ] && DOCKER_ARGS+=(--device=/dev/ttyUSB0:/dev/ttyUSB0)
    [ -c /dev/ttyACM0 ] && DOCKER_ARGS+=(--device=/dev/ttyACM0:/dev/ttyACM0)

    if [ "$SDK" = "psdk" ] && [ "$NO_BULK" -eq 0 ]; then
        # USB bulk: son filesystem virtuales (functionfs), se pasan como bind mount
        DOCKER_ARGS+=(
            -v /dev/usb-ffs/bulk1:/dev/usb-ffs/bulk1
            -v /dev/usb-ffs/bulk2:/dev/usb-ffs/bulk2
        )
    fi
}

# ── Arranque del contenedor ───────────────────────────────────────────────────

if [ "$SDK" = "psdk" ] && [ "$NO_BULK" -eq 0 ]; then
    check_psdk_host_setup
elif [ "$SDK" = "psdk" ] && [ "$NO_BULK" -eq 1 ]; then
    echo "[run] WARN: modo --no-bulk activo. Sin USB bulk endpoints — solo UART disponible."
    echo "[run]       El streaming de video de alta velocidad NO estará disponible."
fi

build_docker_run_args

if [ "$(docker ps -qaf name="^${CONTAINER_NAME}$")" = "" ]; then
    echo "[run] Creando contenedor..."
    docker run -it "${DOCKER_ARGS[@]}" "$IMAGE" bash
else
    if [ "$ACTION" = "restart" ]; then
        echo "[run] Reiniciando contenedor..."
        docker stop "$CONTAINER_NAME" > /dev/null
        docker rm "$CONTAINER_NAME" > /dev/null
        echo "[run] Creando contenedor nuevo..."
        docker run -it "${DOCKER_ARGS[@]}" "$IMAGE" bash
    else
        if ! docker start "$CONTAINER_NAME" > /dev/null; then
            echo "[run] Error al iniciar el contenedor existente."
            exit 1
        fi
        echo "[run] Contenedor $CONTAINER_NAME corriendo."
        docker exec -it "$CONTAINER_NAME" bash --login
    fi
fi

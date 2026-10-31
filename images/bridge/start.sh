#!/bin/bash
# Arranque del bridge del GCS según la distro de la imagen. El entorno ROS + mensajes ya lo cargó el entrypoint.
#   noetic        → multimaster (hosts por MUAV_HOSTS) + rosbridge
#   humble/jazzy  → rosbridge (el descubrimiento lo hace DDS)
set -e

case "$ROS_DISTRO" in
    noetic)
        # Normaliza "a, b ,c" o "[a,b,c]" → "a,b,c"
        HOSTS=$(echo "${MUAV_HOSTS:-}" | tr -d ' []')
        if [ -z "$HOSTS" ]; then
            echo "[bridge] WARN: MUAV_HOSTS vacío → SIN multimaster: solo rosbridge, sin ver ningún dron."
            echo "[bridge]       Ejemplo: MUAV_HOSTS=<gcs>,nvidia,M300-NS-15 ./container_run.sh bridge noetic"
            exec roslaunch /opt/muav/bridge/noetic.launch multimaster:=false
        fi
        # Solo nombres de host / IPs: lo que entra va dentro de una lista YAML.
        if ! [[ "$HOSTS" =~ ^[A-Za-z0-9._-]+(,[A-Za-z0-9._-]+)*$ ]]; then
            echo "[bridge] ERROR: MUAV_HOSTS inválido: '$MUAV_HOSTS' (hosts separados por coma)" >&2
            exit 1
        fi
        echo "[bridge] multimaster hosts: $HOSTS"
        exec roslaunch /opt/muav/bridge/noetic.launch hosts:="$HOSTS"
        ;;
    *)
        exec ros2 launch rosbridge_server rosbridge_websocket_launch.xml
        ;;
esac

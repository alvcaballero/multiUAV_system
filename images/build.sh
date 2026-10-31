#!/bin/bash
# Construye la cadena de imágenes compartidas de una distro, en orden: base → msgs → bridge → dev.
#   images/build.sh <distro> [base] [msgs] [bridge] [dev]     (sin roles = todos)
# Los dispositivos con hardware propio (M300/Jetson) NO salen de aquí: devices/<x>/container_build.sh.
# Al construir dev, genera también el devcontainer de esa distro (.devcontainer/generate.sh: detecta la GPU).
set -e

DISTRO=${1:?Uso: $0 <humble|jazzy|noetic> [base msgs bridge dev]}
shift
ROLES=("$@")
[ ${#ROLES[@]} -eq 0 ] && ROLES=(base msgs bridge dev)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for role in "${ROLES[@]}"; do
    case "$role" in
        base|msgs|bridge|dev) ;;
        *) echo "Rol desconocido: $role (base | msgs | bridge | dev)"; exit 1 ;;
    esac
    echo "[build] muav/$role:$DISTRO"
    docker build \
        -f "$ROOT/images/$role/Dockerfile" \
        --build-arg ROS_DISTRO="$DISTRO" \
        -t "muav/$role:$DISTRO" \
        "$ROOT"
    if [ "$role" = dev ]; then
        "$ROOT/.devcontainer/generate.sh" "$DISTRO"
    fi
done

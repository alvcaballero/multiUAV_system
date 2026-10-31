#!/bin/bash
# Corre en el HOST antes de crear el devcontainer (initializeCommand).
#   .devcontainer/initialize.sh <distro>
# El devcontainer monta $MUAV_WS_<DISTRO> en /ws, igual que ./container_run.sh dev <distro>. Aquí es OBLIGATORIA:
# devcontainer.json no admite un default que dependa de otra variable (probado con el CLI: no anida ${...}).
set -e

DISTRO=${1:?Uso: $0 <distro>}
VAR="MUAV_WS_${DISTRO^^}"
WS="${!VAR:-}"

fail() {
    echo "[devcontainer] ERROR: $1" >&2
    echo "[devcontainer]   Definila donde VS Code la vea (tu ~/.zshrc o ~/.profile) y reabrí VS Code:" >&2
    echo "[devcontainer]     export $VAR=\$HOME/ros2_px4_ws                       # tu workspace" >&2
    echo "[devcontainer]     export $VAR=$(cd "$(dirname "$0")/.." && pwd)/ws/$DISTRO   # el de container_run.sh" >&2
    exit 1
}

[ -n "$WS" ] || fail "$VAR no está definida."
case "$WS" in
    /*) ;;
    *) fail "$VAR='$WS' no es una ruta absoluta (¿un ~ entre comillas?)." ;;
esac
[ -d "$WS" ] || fail "$VAR='$WS' no existe."
mkdir -p "$WS/src"

if ! docker image inspect "muav/dev:$DISTRO" > /dev/null 2>&1; then
    echo "[devcontainer] ERROR: falta la imagen muav/dev:$DISTRO: images/build.sh $DISTRO" >&2
    exit 1
fi

xhost +local:docker > /dev/null 2>&1 || true
echo "[devcontainer] muav/dev:$DISTRO  ws: $WS → /ws"

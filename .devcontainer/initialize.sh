#!/bin/bash
# Corre en el HOST antes de crear el devcontainer (initializeCommand).
#   .devcontainer/initialize.sh <distro>
# Mismo workspace que ./container_run.sh dev <distro>: $MUAV_WS_<DISTRO>, o ws/<distro> de este repo.
set -e

DISTRO=${1:?Uso: $0 <distro>}
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VAR="MUAV_WS_${DISTRO^^}"
WS="${!VAR:-$ROOT/ws/$DISTRO}"
# shellcheck source=../images/dev/ws_guard.sh
source "$ROOT/images/dev/ws_guard.sh"

fail() {
    echo "[devcontainer] ERROR: $1" >&2
    exit 1
}

case "$WS" in
    /*) ;;
    *) fail "$VAR='$WS' no es una ruta absoluta (¿un ~ entre comillas?)." ;;
esac
mkdir -p "$WS/src"

ELSEWHERE=$(muav_ws_built_elsewhere "$WS")
if [ -n "$ELSEWHERE" ]; then
    fail "$WS está compilado FUERA del contenedor ($ELSEWHERE): es un entorno local, montarlo lo rompe.
[devcontainer]   Usá un workspace propio del contenedor: unset $VAR (→ ws/$DISTRO) o apuntala a otro directorio."
fi

if ! docker image inspect "muav/dev:$DISTRO" > /dev/null 2>&1; then
    fail "falta la imagen muav/dev:$DISTRO: images/build.sh $DISTRO"
fi

xhost +local:docker > /dev/null 2>&1 || true
echo "[devcontainer] muav/dev:$DISTRO  ws: $WS → /ws"

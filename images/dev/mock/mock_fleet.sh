#!/bin/bash
# Levanta una flota de drones FALSOS (uav_mock.py) para ver y probar el GCS sin hardware. Reemplaza a
# multiuav_bringup/launch/simulate_{uav,muav}.launch (este repo no tiene paquetes ROS: sin roslaunch).
# Corre en dev:noetic (/opt/muav/mock), con un roscore levantado. Con el bridge dentro, el GCS los ve:
#   ./container_run.sh dev noetic
#   roscore &  /opt/muav/bridge/start.sh &  /opt/muav/mock/mock_fleet.sh
#
#   mock_fleet.sh                                     flota por defecto (la de simulate_muav.launch)
#   mock_fleet.sh "uav_14:dji_M300:37.19:-6.70" ...   flota a medida: ns:categoría:lat:lon
# Categorías: dji_M300 | dji_M600 | px4 (ver dictCategory en uav_mock.py).
# MUAV_MOCK_MEDIA: carpeta para simular descargas (<dir>/mission/* → <dir>/mission_<fecha>/).
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
MEDIA_DIR=${MUAV_MOCK_MEDIA:-/home/user/uav_media}

FLEET=("$@")
if [ ${#FLEET[@]} -eq 0 ]; then
    FLEET=(
        "uav_14:dji_M300:37.193646:-6.70293"
        "uav_17:dji_M600:37.13420794229263:-6.472052460750604"
        "uav_15:dji_M300:37.134207942:-6.472052460750604"
        "uav_3:px4:37.0440984668203:-6.568915045462035"
    )
fi

PIDS=()
# Sin drones lanzados, `kill` falla y con set -e pisaría el código de salida: de ahí el guard y el || true.
trap '[ ${#PIDS[@]} -gt 0 ] && kill "${PIDS[@]}" 2>/dev/null || true' EXIT INT TERM

for spec in "${FLEET[@]}"; do
    IFS=: read -r ns category lat lon <<< "$spec"
    if [ -z "$ns" ] || [ -z "$category" ] || [ -z "$lat" ] || [ -z "$lon" ]; then
        echo "[mock] ERROR: '$spec' no es ns:categoría:lat:lon" >&2
        exit 1
    fi
    echo "[mock] $ns ($category) en $lat,$lon"
    # __name único por dron: en ROS 1 un nodo con el mismo nombre echa al anterior.
    python3 "$HERE/uav_mock.py" "__name:=${ns}_mock" "_ns:=$ns" "_category:=$category" \
        "_lat:=$lat" "_lon:=$lon" "_media_dir:=$MEDIA_DIR" &
    PIDS+=($!)
done

wait

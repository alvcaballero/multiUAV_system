#!/bin/bash
# Entrypoint PSDK. psdk_wrapper lee las credenciales DJI de sus PARÁMETROS ROS (psdk_params.yaml), no de variables
# de entorno: aquí solo se verifica que la config real esté montada (container_run.sh la monta en /root/cfg).

CFG_DIR=/root/cfg

for f in psdk_params.yaml link_config.json; do
    if [ ! -f "$CFG_DIR/$f" ]; then
        echo "[entrypoint_psdk] ERROR: falta $CFG_DIR/$f" >&2
        echo "[entrypoint_psdk]   cp devices/m300/cfg/$f.example devices/m300/cfg/$f   # y completar (psdk/SETUP.md)" >&2
        exit 1
    fi
done

source /opt/ros/humble/setup.bash
source /root/psdk_ws/install/setup.bash

exec "$@"

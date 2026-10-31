#!/bin/bash
# Multimaster del DRON con watchdog. Corre DENTRO del contenedor del dispositivo ROS 1 (/opt/muav/multimaster_watch.sh).
# Origen: multiuav_bringup/devices/init/ros/multimaster.sh: el descubrimiento a veces no engancha al GCS a la primera,
# así que se espera al GCS, se lanza y, si no aparece su master, se relanza.
#
# MUAV_HOSTS: el/los GCS (los mismos que usa /opt/muav/multimaster.launch). Se vigila el PRIMERO.
# Espera a que el roscore del GCS (puerto 11311) responda: no depende de que la imagen tenga ping.
set -u

HOSTS=$(echo "${MUAV_HOSTS:-}" | tr -d ' []')
GCS=${HOSTS%%,*}
if [ -z "$GCS" ]; then
    echo "[multimaster] ERROR: MUAV_HOSTS vacío: no hay GCS que buscar." >&2
    exit 1
fi
LAUNCH=/opt/muav/multimaster.launch
CHECK_EVERY=20

echo "[multimaster] esperando al roscore del GCS en $GCS:11311 ..."
until timeout 2 bash -c "</dev/tcp/$GCS/11311" 2> /dev/null; do
    sleep 5
done

PID=
# Limpieza en EXIT; INT/TERM (Ctrl-C en tmux, docker stop) TERMINAN el script. Un trap en INT/TERM que no sale deja
# el bucle vivo para siempre (pasaba: probado).
trap '[ -n "$PID" ] && kill "$PID" 2>/dev/null' EXIT
trap 'exit 130' INT TERM

while true; do
    echo "[multimaster] lanzando $LAUNCH (hosts: $HOSTS)"
    roslaunch "$LAUNCH" hosts:="$HOSTS" &
    PID=$!
    sleep "$CHECK_EVERY"
    if rosservice call /master_discovery/list_masters 2> /dev/null | grep -q "$GCS"; then
        echo "[multimaster] master del GCS ($GCS) descubierto."
        wait "$PID"
        echo "[multimaster] roslaunch terminó: relanzando."
    else
        echo "[multimaster] el GCS ($GCS) no aparece en list_masters: relanzando."
        kill "$PID" 2> /dev/null
        wait "$PID" 2> /dev/null
    fi
    sleep 5
done

#!/bin/bash
# Pone en hora el dron con la hora del GCS. Las placas sin reloj con batería (Raspberry Pi, Jetson) arrancan con la
# fecha mal, y eso rompe TLS, apt, logs y las descargas por rango de fecha.
# Origen: multiuav_bringup/devices/init/datetime/synchdate.sh. Lo lanza muav-timesync.service al arrancar.
#
# GCS: GET http://$GCS_HOST:$GCS_API_PORT/api/server/datetime → {"datetime": "<ISO 8601>"}
#      (multiuav_gcs: server/routes/server.js, models/server.js).
# Config: /etc/muav/boot.env (GCS_HOST, GCS_API_PORT), ver boot.env.example.
set -u

GCS_HOST=${GCS_HOST:-10.42.0.2}
GCS_API_PORT=${GCS_API_PORT:-4000}
URL="http://$GCS_HOST:$GCS_API_PORT/api/server/datetime"

echo "[timesync] esperando al GCS en $URL ..."
while true; do
    response=$(curl -s --max-time 2 "$URL")
    datetime=$(echo "$response" | grep -o '"datetime": *"[^"]*"' | awk -F'"' '{print $4}')
    if [ -n "$datetime" ]; then
        break
    fi
    sleep 2
done

if date --set "$datetime" > /dev/null; then
    echo "[timesync] hora del GCS aplicada: $datetime"
else
    echo "[timesync] ERROR: date --set '$datetime' falló" >&2
    exit 1
fi

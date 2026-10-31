#!/bin/bash
# Instala en el dron (host, no contenedor) lo que corre al arrancar. Idempotente.
#   sudo devices/common/boot/install.sh
#   - /opt/muav/boot/muav-timesync.sh + muav-timesync.service (hora desde el GCS)
#   - /etc/muav/boot.env (solo si no existe: no pisa la config del dron)
# Reemplaza al esquema viejo /etc/rc.local → /home/ubuntu/init/init.sh. Si el dron todavía lo tiene, quitar la
# línea de init.sh de /etc/rc.local para no sincronizar dos veces.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Ejecutá con sudo: sudo $0"
    exit 1
fi

HERE="$(cd "$(dirname "$0")" && pwd)"

install -d /opt/muav/boot /etc/muav
install -m 0755 "$HERE/muav-timesync.sh" /opt/muav/boot/muav-timesync.sh
install -m 0644 "$HERE/muav-timesync.service" /etc/systemd/system/muav-timesync.service

if [ ! -f /etc/muav/boot.env ]; then
    install -m 0644 "$HERE/boot.env.example" /etc/muav/boot.env
    echo "[install] /etc/muav/boot.env creado: revisá GCS_HOST."
else
    echo "[install] /etc/muav/boot.env ya existe: no se toca."
fi

systemctl daemon-reload
systemctl enable muav-timesync.service
echo "[install] muav-timesync.service habilitado (arranca en el próximo boot; ahora: systemctl start muav-timesync)."

if [ -f /etc/rc.local ] && grep -q "init/init.sh" /etc/rc.local; then
    echo "[install] WARN: /etc/rc.local todavía llama a init/init.sh (esquema viejo): quitá esa línea."
fi

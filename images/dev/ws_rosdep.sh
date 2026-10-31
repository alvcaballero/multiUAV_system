#!/bin/bash
# Instala (apt) las dependencias de los paquetes de /ws/src. No compila.
# Lo corre el devcontainer al crearse (postCreateCommand); en la terminal: /opt/muav/ws_rosdep.sh
# Las dependencias quedan en el CONTENEDOR (no en el host): al recrearlo hay que volver a correrlo. El código y la
# compilación sí quedan en el host (/ws).
set -e

if ! compgen -G "/ws/src/*" > /dev/null; then
    echo "[ws_rosdep] /ws/src vacío: nada que instalar."
    exit 0
fi

# --include-eol-distros: sin él, rosdep update BORRA Noetic del caché (images/base/Dockerfile). Inocuo en Jazzy.
rosdep update --rosdistro "$ROS_DISTRO" --include-eol-distros > /dev/null
apt-get update -qq
# -r: sigue aunque alguna clave no resuelva (paquetes de terceros en /ws/src) y lo informa al final.
rosdep install -y -r -i --rosdistro "$ROS_DISTRO" --from-paths /ws/src

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
# Humble + Harmonic (images/dev/Dockerfile): rosdep resuelve ros_gz_* a los paquetes de FORTRESS, que tienen
# Conflicts con ros-humble-ros-gzharmonic-*: un install -y DESINSTALA Harmonic sin avisar (verificado con apt -s).
# Esas claves ya están cubiertas por gzharmonic: se saltean. Se derivan de lo instalado (ros-<d>-ros-gzharmonic-X →
# ros_gz_X), no de una lista a mano.
SKIP=()
for pkg in $(dpkg-query -W -f '${db:Status-Abbrev} ${Package}\n' "ros-${ROS_DISTRO}-ros-gzharmonic*" 2>/dev/null \
             | awk '$1 == "ii" {print $2}'); do
    suffix=${pkg#ros-"${ROS_DISTRO}"-ros-gzharmonic}
    SKIP+=("ros_gz${suffix//-/_}")
done
[ ${#SKIP[@]} -gt 0 ] && echo "[ws_rosdep] Harmonic instalado: se saltean ${SKIP[*]}"

# -r: sigue aunque alguna clave no resuelva (paquetes de terceros en /ws/src) y lo informa al final.
rosdep install -y -r -i --rosdistro "$ROS_DISTRO" --from-paths /ws/src ${SKIP[@]:+--skip-keys "${SKIP[*]}"}

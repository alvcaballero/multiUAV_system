#!/bin/bash
# PX4 SITL con código completo en /opt/px4/PX4-Autopilot (se puede modificar y recompilar dentro). Uno por distro:
#   noetic  v1.14.4          Gazebo 11: lo instala ubuntu.sh (focal)            make px4_sitl_default gazebo-classic
#   humble  v1.15.4          Harmonic: YA instalado por el Dockerfile. ubuntu.sh v1.15.4 en 22.04 instalaría Garden →
#           (decisión 15)    --no-sim-tools + sus deps de simulación a mano, sin gz-garden (= px4_ros2_docker)
#   jazzy   px4.env          Harmonic: lo instala ubuntu.sh (noble, repo OSRF)  make px4_sitl
#           (decisión 19)
#   install_px4_sitl.sh <distro> <px4.env>
# Clone completo + checkout (no --depth: PX4 saca su versión de los tags). DONT_RUN=1: compila sin abrir el simulador.
# Deja PX4_DIR en /opt/muav/dev_env.sh (bash y zsh, vía muav_env.sh).
set -e

DISTRO=${1:?Uso: $0 <distro> <px4.env>}
PX4_ENV=${2:?Uso: $0 <distro> <px4.env>}
PX4_DIR=/opt/px4/PX4-Autopilot
PX4_REPO=https://github.com/PX4/PX4-Autopilot.git

case "$DISTRO" in
    noetic) REF=v1.14.4; SETUP_ARGS=(--no-nuttx);                 TARGET=(px4_sitl_default gazebo-classic) ;;
    humble) REF=v1.15.4; SETUP_ARGS=(--no-nuttx --no-sim-tools);  TARGET=(px4_sitl) ;;
    jazzy)
        # shellcheck disable=SC1090
        source "$PX4_ENV"
        REF=$PX4_COMMIT; SETUP_ARGS=(--no-nuttx);                 TARGET=(px4_sitl) ;;
    *) echo "[px4] $DISTRO: sin SITL"; exit 0 ;;
esac

git clone "$PX4_REPO" "$PX4_DIR"
cd "$PX4_DIR"
git checkout -q "$REF"
git submodule update --init --recursive -j8
bash Tools/setup/ubuntu.sh "${SETUP_ARGS[@]}"

if [ "$DISTRO" = humble ]; then
    # Lo que ubuntu.sh v1.15.4 instala para simular, menos gz-garden (Tools/setup/ubuntu.sh, bloque INSTALL_SIM).
    apt-get install -y --no-install-recommends \
        dmidecode \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-base \
        gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-ugly \
        gstreamer1.0-libav \
        gstreamer1.0-gl \
        libeigen3-dev \
        libgstreamer-plugins-base1.0-dev \
        libimage-exiftool-perl \
        libopencv-dev \
        libxml2-utils \
        pkg-config \
        protobuf-compiler
fi
rm -rf /var/lib/apt/lists/*

DONT_RUN=1 make "${TARGET[@]}"
echo "export PX4_DIR=$PX4_DIR" >> /opt/muav/dev_env.sh
echo "[px4] $DISTRO: $(git describe --tags --always) en $PX4_DIR"

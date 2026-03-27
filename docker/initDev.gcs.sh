#!/bin/bash
# initDev.gcs.sh — pobla el volumen para desarrollo GCS (sin PX4/Gazebo)
# Ejecutar UNA vez dentro del contenedor después de crearlo.
# Uso: docker exec -it px4_noetic bash /app/initDev.sh
#
# El volumen debe estar montado en /app antes de ejecutar este script.
# Tiempo estimado: 10-15 min (solo catkin_make, sin PX4)

set -euo pipefail

APP=/app

# ── 1. Onboard-SDK (dependencia de Onboard-SDK-ROS) ───────────────────────────
if [ ! -d "$APP/Onboard-SDK" ]; then
    echo "[INFO] Clonando Onboard-SDK..."
    cd "$APP"
    git clone https://github.com/dji-sdk/Onboard-SDK.git
    cd Onboard-SDK
    mkdir build && cd build
    cmake ..
    sudo make -j$(nproc) install
    echo "[INFO] Onboard-SDK instalado."
else
    echo "[SKIP] Onboard-SDK ya existe."
fi

# ── 2. Paquetes catkin ─────────────────────────────────────────────────────────
mkdir -p "$APP/catkin_ws/src"
cd "$APP/catkin_ws/src"

clone_if_missing() {
    local name="$1"
    local url="$2"
    shift 2
    if [ ! -d "$name" ]; then
        echo "[INFO] Clonando $name..."
        git clone "$@" "$url" "$name"
    else
        echo "[SKIP] $name ya existe."
    fi
}

clone_if_missing multiUAV_system  https://github.com/alvcaballero/multiUAV_system.git  --recurse-submodules -j8 --branch GimbalPitch
clone_if_missing ros_rtsp          https://github.com/CircusMonkey/ros_rtsp.git
clone_if_missing simple_vs         https://github.com/miggilcas/simple_vs.git
clone_if_missing grvc-utils        https://github.com/arpoma16/grvc-utils.git          --branch noetic
clone_if_missing Onboard-SDK-ROS   https://github.com/miggilcas/Onboard-SDK-ROS.git

# ── 3. catkin_make ─────────────────────────────────────────────────────────────
cd "$APP/catkin_ws"
echo "[INFO] Compilando workspace..."
source /opt/ros/noetic/setup.bash
catkin_make -j$(nproc)

echo ""
echo "[OK] Workspace GCS listo. Reiniciá el contenedor para que el .bashrc surta efecto."

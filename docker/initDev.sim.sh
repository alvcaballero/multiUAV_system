#!/bin/bash
# initDev.sim.sh — pobla el volumen para simulación completa (PX4 SITL + Gazebo)
# Ejecutar UNA vez dentro del contenedor después de crearlo.
# Uso: docker exec -it muavgcs_ros1_sim bash /app/initDev.sh
#
# IMPORTANTE: ejecutar initDev.gcs.sh primero — este script asume que
# Onboard-SDK y el catkin_ws ya están compilados.
#
# Tiempo estimado: 30-40 min adicionales (PX4 + Gazebo es pesado)

set -euo pipefail

APP=/app

# ── Verificar que el workspace GCS ya existe ──────────────────────────────────
if [ ! -f "$APP/catkin_ws/devel/setup.bash" ]; then
    echo "[ERROR] catkin_ws no compilado. Ejecutá initDev.gcs.sh primero."
    exit 1
fi

# ── PX4-Autopilot ─────────────────────────────────────────────────────────────
if [ ! -d "$APP/PX4-Autopilot" ]; then
    echo "[INFO] Clonando PX4-Autopilot v1.14.4..."
    cd "$APP"
    git clone --recurse-submodules -j8 --branch v1.14.4 \
        https://github.com/PX4/PX4-Autopilot.git
    cd PX4-Autopilot
    echo "[INFO] Compilando PX4 SITL con Gazebo (esto tarda ~30 min)..."
    make px4_sitl_default gazebo-classic
    echo "[INFO] PX4 compilado."
else
    echo "[SKIP] PX4-Autopilot ya existe."
fi

echo ""
echo "[OK] Volumen sim listo."
echo "Para lanzar la simulación:"
echo "  source /app/PX4-Autopilot/Tools/simulation/gazebo-classic/setup_gazebo.bash \\"
echo "         /app/PX4-Autopilot /app/PX4-Autopilot/build/px4_sitl_default"
echo "  roslaunch px4 posix_sitl.launch"

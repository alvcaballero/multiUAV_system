#!/bin/bash
# Micro-XRCE-DDS Agent en dev, la versión de devices/px4_ros2/agent.repos (la misma que el dron).
#   install_agent.sh <distro> <agent.repos>
# Cada distro como su ROS permite (verificado en el CMakeLists de v2.4.3):
#   jazzy (y posteriores): colcon. Su colcon.pkg fuerza el Fast-DDS de /opt/ros, que pide fastcdr 2 (Jazzy lo trae).
#     → /opt/muav/tools (capa de muav_env.sh)
#   humble: cmake superbuild. Humble trae fastcdr 1.0.x: con el del sistema no compila. La superbuild baja su propio
#     Fast-DDS 2.14 + fastcdr 2.2 (sonames distintos de los de ROS: conviven). Igual que px4_ros2_docker.
#     → /usr/local
set -e

DISTRO=${1:?Uso: $0 <distro> <agent.repos>}
REPOS=${2:?Uso: $0 <distro> <agent.repos>}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/src"
vcs import --input "$REPOS" "$TMP/src"
AGENT_SRC="$TMP/src/Micro-XRCE-DDS-Agent"

case "$DISTRO" in
    humble)
        cmake -S "$AGENT_SRC" -B "$TMP/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local
        cmake --build "$TMP/build" -j "$(nproc)"
        cmake --install "$TMP/build"
        ldconfig
        ;;
    *)
        mkdir -p /opt/muav/tools
        # shellcheck disable=SC1090
        source "/opt/ros/$DISTRO/setup.bash"
        cd /opt/muav/tools
        colcon build --merge-install --base-paths "$TMP/src" --packages-select microxrcedds_agent \
            --cmake-args -DCMAKE_BUILD_TYPE=Release
        rm -rf build log
        ;;
esac
echo "[agent] $(command -v MicroXRCEAgent || echo /opt/muav/tools/bin/MicroXRCEAgent)"

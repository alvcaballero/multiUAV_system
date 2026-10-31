# Carga el entorno ROS en capas: distro → mensajes del sistema (contrato) → herramientas (/opt/muav/tools: Agent
# XRCE-DDS en dev) → workspace del dispositivo (MUAV_WS, si la imagen lo define) → workspace montado (/ws).
# Se hace `source`, no se ejecuta. Orden importa: cada capa hace overlay de la anterior.
# bash (.bashrc, entrypoint) y zsh (.zshrc del devcontainer): cada shell usa su setup.<shell>; ROS, colcon y catkin
# generan los dos.

if [ -n "${ZSH_VERSION:-}" ]; then _muav_sh=zsh; else _muav_sh=bash; fi

source "/opt/ros/${ROS_DISTRO}/setup.${_muav_sh}"

for ws in /opt/muav/msgs /opt/muav/tools ${MUAV_WS:-} /ws; do
    if [ -f "$ws/install/setup.${_muav_sh}" ]; then
        source "$ws/install/setup.${_muav_sh}"
    elif [ -f "$ws/devel/setup.${_muav_sh}" ]; then
        source "$ws/devel/setup.${_muav_sh}"
    fi
done
unset ws _muav_sh

# Carga el entorno ROS en capas: distro → mensajes del sistema (contrato) → workspace del dispositivo (MUAV_WS, si
# la imagen lo define) → workspace montado (/ws).
# Se hace `source`, no se ejecuta. Orden importa: cada capa hace overlay de la anterior.

source "/opt/ros/${ROS_DISTRO}/setup.bash"

for ws in /opt/muav/msgs ${MUAV_WS:-} /ws; do
    if [ -f "$ws/install/setup.bash" ]; then
        source "$ws/install/setup.bash"
    elif [ -f "$ws/devel/setup.bash" ]; then
        source "$ws/devel/setup.bash"
    fi
done

#!/bin/bash
# Permitir que Docker acceda a las ventanas de X11 (Interfaz gráfica)
xhost +local:docker > /dev/null

# Configuración de rutas (Asegúrate de que esta carpeta exista en tu Jetson)
PROJECT_DIR="${HOME}/app_ros1";
PROJECT_DIST="/root/app_ws/src/external";
CONTAINER_NAME="muavgcs_noetic"
USER_CONFIG_HOST="$(dirname "$0")/UserConfig.txt"
USER_CONFIG_CONTAINER="/root/Onboard-SDK/build/bin/UserConfig.txt"

# Crear la carpeta si no existe para evitar errores de montaje
mkdir -p "$PROJECT_DIR"

echo "Directorio del proyecto en la Jetson: $PROJECT_DIR"

# Verificar si el contenedor ya existe
if [ "$(docker ps -qaf name="$CONTAINER_NAME")" = "" ]; then
    echo 'Contenedor no encontrado, creando y arrancando con soporte NVIDIA...';
    
    docker run -it \
        --name "$CONTAINER_NAME" \
        --privileged \
        --runtime nvidia \
        --network host \
        --workdir "$PROJECT_DIST" \
        --env DISPLAY=$DISPLAY \
        --env NVIDIA_DRIVER_CAPABILITIES=all \
        --device=/dev/ttyUSB0:/dev/ttyUSB0 \
        --device=/dev/ttyACM0:/dev/ttyACM0 \
        -v /dev/bus/usb:/dev/bus/usb \
        --volume /tmp/.X11-unix:/tmp/.X11-unix \
        --volume "$PROJECT_DIR":"$PROJECT_DIST" \
        --volume "$USER_CONFIG_HOST":"$USER_CONFIG_CONTAINER":ro \
        ros-noetic-muavs:l4t-r36.4.7 \
        bash
else
    # Si el contenedor existe pero está apagado, lo enciende
    if [ "${1}" = "restart" ]; then
        echo 'Reiniciando contenedor...';
        docker stop "$CONTAINER_NAME" > /dev/null
    fi
    
    if ! docker start "$CONTAINER_NAME" > /dev/null; then
        echo 'Error al iniciar el contenedor existente.';
        exit 1
    fi
    
    echo "CONTAINER $CONTAINER_NAME RUNNING";
    docker exec -it "$CONTAINER_NAME" bash --login
fi

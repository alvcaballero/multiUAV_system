# Bridge del GCS: rosbridge con los mensajes del contrato. Uno por distro (decisión 4).
#   docker build -f images/bridge/Dockerfile --build-arg ROS_DISTRO=humble -t muav/bridge:humble .
#   ./container_run.sh bridge humble
#   MUAV_HOSTS=<gcs>,<dron1>,<dron2> ./container_run.sh bridge noetic
# Noetic agrega multimaster (decisión 10): reemplaza a connect_uas.launch con los hosts por MUAV_HOSTS.
ARG ROS_DISTRO=humble
ARG BASE_IMAGE=muav/msgs:${ROS_DISTRO}
FROM ${BASE_IMAGE}

ARG ROS_DISTRO
ARG DEBIAN_FRONTEND=noninteractive

# multimaster de apt (1.3.2): la misma versión que la imagen que hoy funciona con la flota (muavgcs:noetic). Los
# drones lo compilan desde fuente (noetic-devel @ 143f8e4), que también es la 1.3.2. Noetic está en EOL: apt ya no cambia.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-${ROS_DISTRO}-rosbridge-server \
    && if [ "$ROS_DISTRO" = noetic ]; then \
        apt-get install -y --no-install-recommends \
            ros-noetic-fkie-master-discovery \
            ros-noetic-fkie-master-sync; \
       fi \
    && rm -rf /var/lib/apt/lists/*

COPY images/bridge/start.sh images/bridge/noetic.launch /opt/muav/bridge/
RUN chmod +x /opt/muav/bridge/start.sh

CMD ["/opt/muav/bridge/start.sh"]

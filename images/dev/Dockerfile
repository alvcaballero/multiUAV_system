# Desarrollo: mismos mensajes que producción + herramientas + bridge dentro (decisión 13).
# El código se monta en /ws desde ws/<distro> (container_run.sh dev <distro>): se edita en el host, se compila aquí.
#   docker build -f images/dev/Dockerfile --build-arg ROS_DISTRO=humble -t muav/dev:humble .
#   images/build.sh noetic dev
#
# noetic además trae lo necesario para compilar el código de los drones ROS 1 en /ws y simular PX4:
#   - Onboard-SDK instalado (dji_osdk_ros COMPLETO se puede compilar en /ws; /opt/muav/msgs lo trae solo-interfaces)
#   - mavros, multimaster, GStreamer RTSP, libusb/ffmpeg (lo que no declaran los package.xml)
#   - PX4 v1.14.4 SITL + Gazebo 11 compilado en /opt/px4 (WITH_PX4_SIM=false para no incluirlo: ~5 GB y ~30 min)
#     Antes: docker/Dockerfile.sim + initDev.sim.sh, clonado y compilado A MANO en el volumen.
ARG ROS_DISTRO=humble
ARG BASE_IMAGE=muav/msgs:${ROS_DISTRO}
FROM ${BASE_IMAGE}

ARG ROS_DISTRO
ARG DEBIAN_FRONTEND=noninteractive
ARG WITH_PX4_SIM=true
ARG PX4_VERSION=v1.14.4
# Onboard-SDK: el mismo commit que los drones OSDK.
ARG OSDK_VERSION=118e2825a347499efb8ed253146552c5b9b10779

# Común a todas las distros
RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-${ROS_DISTRO}-desktop \
        ros-${ROS_DISTRO}-rosbridge-server \
        build-essential \
        gdb \
        tmux \
    && rm -rf /var/lib/apt/lists/*

# Por distro: ros-dev-tools solo existe en ROS 2.
RUN apt-get update \
    && if [ "$ROS_DISTRO" = noetic ]; then \
        apt-get install -y --no-install-recommends \
            ros-noetic-fkie-master-discovery \
            ros-noetic-fkie-master-sync \
            ros-noetic-mavros \
            ros-noetic-mavros-extras \
            libusb-1.0-0-dev \
            ffmpeg \
            libavcodec-dev \
            libavformat-dev \
            libswscale-dev \
            libswresample-dev \
            libgstreamer-plugins-base1.0-dev \
            libgstrtspserver-1.0-dev \
            gstreamer1.0-plugins-good \
            gstreamer1.0-plugins-bad \
            gstreamer1.0-plugins-ugly \
            gstreamer1.0-rtsp \
            gstreamer1.0-tools; \
       else \
        apt-get install -y --no-install-recommends ros-dev-tools; \
       fi \
    && rm -rf /var/lib/apt/lists/*

# noetic: Onboard-SDK + datasets de mavros (sin ellos mavros aborta al arrancar).
COPY devices/common/osdk/install_osdk.sh /tmp/install_osdk.sh
RUN if [ "$ROS_DISTRO" = noetic ]; then \
        /tmp/install_osdk.sh ${OSDK_VERSION} \
        && /opt/ros/noetic/lib/mavros/install_geographiclib_datasets.sh; \
    fi

# noetic: PX4 SITL + Gazebo 11. Tools/setup/ubuntu.sh es el script oficial de PX4: en focal instala Gazebo 11
# (repo OSRF) y las deps de Python. --no-nuttx: sin toolchain ARM (no hace falta para SITL).
# DONT_RUN=1: compila sin abrir Gazebo (no hay display en el build).
RUN if [ "$ROS_DISTRO" = noetic ] && [ "$WITH_PX4_SIM" = true ]; then \
        git clone --recurse-submodules -j8 --branch ${PX4_VERSION} \
            https://github.com/PX4/PX4-Autopilot.git /opt/px4/PX4-Autopilot \
        && bash /opt/px4/PX4-Autopilot/Tools/setup/ubuntu.sh --no-nuttx \
        && rm -rf /var/lib/apt/lists/* \
        && cd /opt/px4/PX4-Autopilot \
        && DONT_RUN=1 make px4_sitl_default gazebo-classic \
        && echo 'export PX4_DIR=/opt/px4/PX4-Autopilot' >> /root/.bashrc; \
    fi

# Bridge dentro (decisión 13): los mismos archivos que bridge:<distro>.
#   /opt/muav/bridge/start.sh       (noetic: MUAV_HOSTS=<drones> para el multimaster)
COPY images/bridge/start.sh images/bridge/noetic.launch images/bridge/multimaster.launch /opt/muav/bridge/
RUN chmod +x /opt/muav/bridge/start.sh

WORKDIR /ws

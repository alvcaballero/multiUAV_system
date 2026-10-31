# VTOL: PX4 por mavros (Raspberry Pi, arm64, sin GPU). ROS 1 Noetic.
# Base: muav/base:noetic de images/, construida EN la Pi (multi-arch, apt de Noetic para focal arm64).
#   images/build.sh noetic base && devices/vtol/container_build.sh
# Build context: la RAÍZ del repo.
#
# Hereda muav/base (no muav/msgs): el workspace importa el contrato con vcs y compila solo lo que necesita, igual que
# los demás dispositivos.
ARG BASE_IMAGE=muav/base:noetic
FROM ${BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive
# Paquetes raíz del VTOL. px4_bringup va explícito: onboard_px4 lo usa desde atlas.launch, no desde package.xml.
ARG DEVICE_PACKAGES="onboard_px4 px4_bringup"

# Cámara (gst-launch: v4l2src → x264enc → rtspclientsink) + multimaster por apt.
RUN apt-get update && apt-get install -y --no-install-recommends \
        gstreamer1.0-tools \
        gstreamer1.0-plugins-base \
        gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-ugly \
        gstreamer1.0-rtsp \
        ros-noetic-fkie-master-discovery \
        ros-noetic-fkie-master-sync \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root/app_ws
# Mismo nombre en origen (noetic.repos): se copian con el nombre de su rol para no pisarse.
COPY images/msgs/noetic.repos /root/app_ws/repos/contract.repos
COPY devices/vtol/noetic.repos /root/app_ws/repos/device.repos
RUN mkdir -p src/external \
    && vcs import --input repos/contract.repos src \
    && vcs import --input repos/device.repos src

SHELL ["/bin/bash", "-c"]
# rosdep SOLO sobre lo que se compila: grvc-ual y grvc-utils traen paquetes de Gazebo/UE/DJI que el dron no usa.
# gazebo_ros: run_depend de px4_bringup, solo para el modo sitl (atlas.launch usa mode=custom). Sin él no se instala
# Gazebo en la Pi.
RUN source /opt/ros/noetic/setup.bash \
    && PKG_PATHS=$(colcon list --paths-only --packages-up-to ${DEVICE_PACKAGES}) \
    && echo "[vtol] se compila: $(colcon list --names-only --packages-up-to ${DEVICE_PACKAGES} | tr '\n' ' ')" \
    && apt-get update \
    && rosdep install -y -i --rosdistro noetic --from-paths ${PKG_PATHS} --skip-keys gazebo_ros \
    && rm -rf /var/lib/apt/lists/* \
    && catkin_make --only-pkg-with-deps ${DEVICE_PACKAGES} -DCATKIN_ENABLE_TESTING=OFF

# mavros necesita los datasets de GeographicLib (geoid) o aborta al arrancar.
RUN /opt/ros/noetic/lib/mavros/install_geographiclib_datasets.sh

# El entrypoint de muav/base carga ROS + este workspace (MUAV_WS) en docker run, y .bashrc en docker exec.
ENV MUAV_WS=/root/app_ws

# Multimaster del dron: el mismo launch que bridge:noetic, con los hosts del GCS por MUAV_HOSTS.
COPY images/bridge/multimaster.launch /opt/muav/multimaster.launch

WORKDIR /root/app_ws

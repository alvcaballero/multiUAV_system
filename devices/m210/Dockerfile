# M210 por OSDK (Raspberry Pi, arm64, sin GPU). ROS 1 Noetic.
# Base: muav/base:noetic de images/, construida EN la Pi (ros:noetic-ros-base es multi-arch: hay apt de Noetic para
# Ubuntu 20.04 arm64, así que no hace falta compilar ROS desde fuentes como en el Jetson del M300).
#   images/build.sh noetic base && devices/m210/container_build.sh
# Build context: la RAÍZ del repo.
#
# No hereda muav/msgs:noetic: ahí dji_osdk_ros está compilado solo-interfaces, y el dron lo necesita COMPLETO.
# Importa el contrato con vcs, igual que el M300 (decisión 6).
ARG BASE_IMAGE=muav/base:noetic
FROM ${BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive
# Onboard-SDK: master @ 4.1.0-34, el mismo que el M300.
ARG OSDK_VERSION=118e2825a347499efb8ed253146552c5b9b10779
# Paquetes raíz del M210: se compilan ellos y sus dependencias del workspace, nada más.
#   onboard_dji (misión, arrastra dji_osdk_ros + aerialcore_common), simple_vs + ros_rtsp (vídeo).
ARG DEVICE_PACKAGES="onboard_dji simple_vs ros_rtsp"

# Sistema: lo que no declaran los package.xml (dji_osdk_ros completo pide LibUSB y FFMPEG; ros_rtsp, gst-rtsp-server)
# + multimaster por apt.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        libusb-1.0-0-dev \
        ffmpeg \
        libavcodec-dev \
        libavformat-dev \
        libavutil-dev \
        libswscale-dev \
        libswresample-dev \
        libgstreamer1.0-dev \
        libgstreamer-plugins-base1.0-dev \
        libgstrtspserver-1.0-dev \
        gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-ugly \
        gstreamer1.0-rtsp \
        ros-noetic-fkie-master-discovery \
        ros-noetic-fkie-master-sync \
    && rm -rf /var/lib/apt/lists/*

COPY devices/common/osdk/install_osdk.sh /tmp/install_osdk.sh
RUN /tmp/install_osdk.sh ${OSDK_VERSION}

WORKDIR /root/app_ws
# Mismo nombre en origen (noetic.repos): se copian con el nombre de su rol para no pisarse.
COPY images/msgs/noetic.repos /root/app_ws/repos/contract.repos
COPY devices/m210/noetic.repos /root/app_ws/repos/device.repos
RUN mkdir -p src/external \
    && vcs import --input repos/contract.repos src \
    && vcs import --input repos/device.repos src

SHELL ["/bin/bash", "-c"]
# catkin_make (devel space), igual que el M300: el entrypoint reescribe el launch de dji_osdk_ros en src/.
RUN source /opt/ros/noetic/setup.bash \
    && apt-get update \
    && rosdep install -y -i --rosdistro noetic --from-paths src \
    && rm -rf /var/lib/apt/lists/* \
    && catkin_make --only-pkg-with-deps ${DEVICE_PACKAGES} -DCATKIN_ENABLE_TESTING=OFF

RUN echo "source /root/app_ws/devel/setup.bash" >> /root/.bashrc

# Multimaster del dron: el mismo launch que bridge:noetic, con los hosts del GCS por MUAV_HOSTS.
COPY images/bridge/multimaster.launch /opt/muav/multimaster.launch
# Con watchdog: espera al GCS y relanza si no lo descubre (devices/common/multimaster_watch.sh).
COPY devices/common/multimaster_watch.sh /opt/muav/multimaster_watch.sh

# DJI MatriceSeries ConfigTool (armv8). La config REAL (credenciales) se monta en /root/cfg (container_run.sh).
RUN echo 'SIM_LAT=37.4103824' >> /root/.bashrc && \
    echo 'SIM_LON=-6.0020946' >> /root/.bashrc && \
    echo 'alias M210-real="/root/Onboard-SDK/utility/bin/armv8/64-bit/MatriceSeries_ConfigTool --usb-port /dev/ttyACM0 --config-file /root/cfg/UserConfig_osdk.txt --power-supply on"' >> /root/.bashrc && \
    echo 'alias M210-sim-on="/root/Onboard-SDK/utility/bin/armv8/64-bit/MatriceSeries_ConfigTool --usb-port /dev/ttyACM0 --config-file /root/cfg/UserConfig_osdk.txt --power-supply on --usb-connected-flight on --simulation on --latitude $SIM_LAT --longitude $SIM_LON"' >> /root/.bashrc

COPY devices/common/osdk/entrypoint_osdk.sh /root/entrypoint_osdk.sh
RUN chmod +x /root/entrypoint_osdk.sh

WORKDIR /root/app_ws
ENTRYPOINT ["/root/entrypoint_osdk.sh"]
CMD ["bash"]

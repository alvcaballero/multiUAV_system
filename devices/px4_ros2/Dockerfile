# Dron PX4 por ROS 2 (uXRCE-DDS): Agent + translation node + MUAV_px4_offboard + mqtt_client. ROS 2 Jazzy.
# Base: muav/base:<distro> de images/ (multi-arch): x86 o una companion arm64 (Pi, Jetson; el contenedor es Ubuntu
# 24.04 aunque el host no lo sea, no hace falta CUDA).
#   images/build.sh jazzy base && devices/px4_ros2/container_build.sh
# Build context: la RAÍZ del repo.
#
# ARG ROS_DISTRO genérico, pero solo existe jazzy.repos: el perfil Humble mandaría al GCS la estructura de
# px4_msgs v1.15.4 (ver README). Construirlo con humble falla en el COPY, a propósito.
# Hereda muav/base (no muav/msgs): importa el contrato con vcs y compila solo lo que piden sus package.xml.
ARG ROS_DISTRO=jazzy
ARG BASE_IMAGE=muav/base:${ROS_DISTRO}
FROM ${BASE_IMAGE}

ARG ROS_DISTRO
ARG DEBIAN_FRONTEND=noninteractive
# Paquetes raíz. mqtt_client entra por muav_px4_offboard (exec_depend). microxrcedds_agent es cmake puro (sin
# package.xml): sus deps (Fast-DDS) vienen con ROS.
ARG DEVICE_PACKAGES="muav_px4_offboard microxrcedds_agent translation_node"

WORKDIR /root/app_ws
# Mismo nombre en origen (<distro>.repos): se copian con el nombre de su rol para no pisarse.
COPY images/msgs/${ROS_DISTRO}.repos /root/app_ws/repos/contract.repos
COPY devices/px4_ros2/${ROS_DISTRO}.repos /root/app_ws/repos/device.repos
COPY devices/px4_ros2/px4.env devices/px4_ros2/fetch_translation_node.sh /opt/muav/px4/
RUN mkdir -p src/external \
    && vcs import --input repos/contract.repos src \
    && vcs import --input repos/device.repos src \
    && /opt/muav/px4/fetch_translation_node.sh src

SHELL ["/bin/bash", "-c"]
RUN source /opt/ros/${ROS_DISTRO}/setup.bash \
    && PKG_PATHS=$(colcon list --paths-only --packages-up-to ${DEVICE_PACKAGES}) \
    && echo "[px4_ros2] se compila: $(colcon list --names-only --packages-up-to ${DEVICE_PACKAGES} | tr '\n' ' ')" \
    && apt-get update \
    && rosdep install -y -i --rosdistro ${ROS_DISTRO} --from-paths ${PKG_PATHS} \
    && rm -rf /var/lib/apt/lists/* \
    && colcon build --packages-up-to ${DEVICE_PACKAGES} \
        --cmake-args -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
    && rm -rf build log

# El entrypoint de muav/base carga ROS + este workspace (MUAV_WS) en docker run, y .bashrc en docker exec.
ENV MUAV_WS=/root/app_ws

WORKDIR /root/app_ws

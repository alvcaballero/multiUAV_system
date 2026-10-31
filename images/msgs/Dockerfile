# Mensajes del sistema (el contrato: images/msgs/<distro>.repos) compilados en /opt/muav/msgs.
#   docker build -f images/msgs/Dockerfile --build-arg ROS_DISTRO=humble -t muav/msgs:humble .
# Mismo Dockerfile para noetic (catkin), humble y jazzy (ament): colcon compila los dos tipos de paquete
# (colcon-ros pasa -DCATKIN_INSTALL_INTO_PREFIX_ROOT=0 y agrega el hook de ROS_PACKAGE_PATH a los catkin).
ARG ROS_DISTRO=humble
ARG BASE_IMAGE=muav/base:${ROS_DISTRO}
FROM ${BASE_IMAGE}

ARG ROS_DISTRO
ARG DEBIAN_FRONTEND=noninteractive
# Qué paquetes del .repos son "mensajes". Un repo puede traer más (psdk_ros2 trae psdk_wrapper): esos no se compilan
# aquí, los compila el dispositivo que los necesita. Nombres explícitos para lo que no sigue la convención:
#   aerialcore_common → nombre viejo de multiuav_interfaces (en transición, decisión 8)
#   dji_osdk_ros      → mensajes + nodos en un solo paquete; aquí solo interfaces (ver MSGS_CMAKE_ARGS)
ARG MSGS_REGEX='.*_(msgs|interfaces)$|^aerialcore_common$|^dji_osdk_ros$'
# ONBOARD_SDK_ROS_ONLY_INTERFACES: dji_osdk_ros sin nodos ni Onboard-SDK (decisión 7). Los paquetes que no la usan
# la ignoran (CMake solo avisa de una variable sin usar).
ARG MSGS_CMAKE_ARGS='-DONBOARD_SDK_ROS_ONLY_INTERFACES=ON -DCATKIN_ENABLE_TESTING=OFF -DBUILD_TESTING=OFF'

WORKDIR /opt/muav/msgs
COPY images/msgs/${ROS_DISTRO}.repos msgs.repos

RUN mkdir -p src && vcs import --input msgs.repos src

SHELL ["/bin/bash", "-c"]
RUN source /opt/ros/${ROS_DISTRO}/setup.bash \
    && PKG_PATHS=$(colcon list --paths-only --packages-select-regex "${MSGS_REGEX}") \
    && PKGS=$(colcon list --names-only --packages-select-regex "${MSGS_REGEX}") \
    && echo "[msgs] ${ROS_DISTRO}: ${PKGS//$'\n'/ }" \
    && apt-get update \
    && rosdep install -y -i --rosdistro ${ROS_DISTRO} --from-paths ${PKG_PATHS} \
    && rm -rf /var/lib/apt/lists/* \
    && colcon build --merge-install --packages-select ${PKGS} ${MSGS_CMAKE_ARGS:+--cmake-args ${MSGS_CMAKE_ARGS}} \
    && rm -rf build log

WORKDIR /root

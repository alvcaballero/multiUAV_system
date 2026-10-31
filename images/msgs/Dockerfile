# Mensajes del sistema (el contrato: images/msgs/<distro>.repos) compilados en /opt/muav/msgs.
#   docker build -f images/msgs/Dockerfile --build-arg ROS_DISTRO=humble -t muav/msgs:humble .
# Solo ROS 2 por ahora; Noetic (catkin) entra en R2.
ARG ROS_DISTRO=humble
ARG BASE_IMAGE=muav/base:${ROS_DISTRO}
FROM ${BASE_IMAGE}

ARG ROS_DISTRO
ARG DEBIAN_FRONTEND=noninteractive
# Qué paquetes del .repos son "mensajes". Un repo puede traer más (psdk_ros2 trae psdk_wrapper): esos no se
# compilan aquí, los compila el dispositivo que los necesita.
ARG MSGS_REGEX='.*_(msgs|interfaces)$'

WORKDIR /opt/muav/msgs
COPY images/msgs/${ROS_DISTRO}.repos msgs.repos

RUN mkdir -p src && vcs import --input msgs.repos src

SHELL ["/bin/bash", "-c"]
RUN source /opt/ros/${ROS_DISTRO}/setup.bash \
    && PKG_PATHS=$(colcon list --paths-only --packages-select-regex "${MSGS_REGEX}") \
    && PKGS=$(colcon list --names-only --packages-select-regex "${MSGS_REGEX}") \
    && echo "[msgs] paquetes: ${PKGS//$'\n'/ }" \
    && apt-get update \
    && rosdep install -y -i --rosdistro ${ROS_DISTRO} --from-paths ${PKG_PATHS} \
    && rm -rf /var/lib/apt/lists/* \
    && colcon build --merge-install --packages-select ${PKGS} \
    && rm -rf build log

WORKDIR /root

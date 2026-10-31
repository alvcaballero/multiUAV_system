# Desarrollo: mismos mensajes que producción + herramientas + bridge dentro (decisión 13).
# El código se monta en /ws desde ws/<distro> (container_run.sh dev <distro>): se edita en el host, se compila aquí.
#   docker build -f images/dev/Dockerfile --build-arg ROS_DISTRO=humble -t muav/dev:humble .
ARG ROS_DISTRO=humble
ARG BASE_IMAGE=muav/msgs:${ROS_DISTRO}
FROM ${BASE_IMAGE}

ARG ROS_DISTRO
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-${ROS_DISTRO}-desktop \
        ros-${ROS_DISTRO}-rosbridge-server \
        ros-dev-tools \
        build-essential \
        gdb \
        tmux \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /ws

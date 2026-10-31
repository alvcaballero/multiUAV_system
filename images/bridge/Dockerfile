# Bridge del GCS: rosbridge con los mensajes del contrato. Uno por distro (decisión 4).
#   docker build -f images/bridge/Dockerfile --build-arg ROS_DISTRO=humble -t muav/bridge:humble .
#   docker run --rm --network host muav/bridge:humble
# Noetic (multimaster + MUAV_HOSTS, decisión 10) entra en R2.
ARG ROS_DISTRO=humble
ARG BASE_IMAGE=muav/msgs:${ROS_DISTRO}
FROM ${BASE_IMAGE}

ARG ROS_DISTRO
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-${ROS_DISTRO}-rosbridge-server \
    && rm -rf /var/lib/apt/lists/*

CMD ["ros2", "launch", "rosbridge_server", "rosbridge_websocket_launch.xml"]

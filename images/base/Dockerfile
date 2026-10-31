# Base ROS de una distro: herramientas comunes a msgs, bridge, dev y dispositivos x86.
#   docker build -f images/base/Dockerfile --build-arg ROS_DISTRO=humble -t muav/base:humble .
# Build context: la RAÍZ del repo (ver images/build.sh).
ARG ROS_DISTRO=humble
FROM ros:${ROS_DISTRO}-ros-base

ARG ROS_DISTRO
ARG DEBIAN_FRONTEND=noninteractive

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Europe/Madrid

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# colcon en TODAS las distros: compila también paquetes catkin (colcon-ros), así msgs/bridge/dev usan los mismos
# comandos en noetic, humble y jazzy. catkin-tools queda en noetic para quien desarrolle con `catkin build`.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        nano \
        python3-colcon-common-extensions \
        python3-pip \
        python3-vcstool \
        tzdata \
    && if [ "$ROS_DISTRO" = noetic ]; then \
        apt-get install -y --no-install-recommends python3-catkin-tools; \
       fi \
    && rm -rf /var/lib/apt/lists/*

# Noetic está en EOL (mayo 2025): un `rosdep update` normal BORRA sus reglas del caché y rosdep deja de resolver
# claves como nmea_msgs (verificado). Siempre con --include-eol-distros.
RUN if [ "$ROS_DISTRO" = noetic ]; then \
        rosdep update --rosdistro noetic --include-eol-distros \
        && echo "alias rosdep-update='rosdep update --include-eol-distros'  # Noetic es EOL: ver images/base/Dockerfile" >> /root/.bashrc; \
    fi

# Un único punto que carga ROS + workspace de mensajes + workspace montado (/ws).
# El entrypoint lo usa en `docker run`; .bashrc en `docker exec`.
COPY images/base/muav_env.sh /opt/muav/muav_env.sh
COPY images/base/entrypoint.sh /opt/muav/entrypoint.sh
RUN chmod +x /opt/muav/entrypoint.sh \
    && echo "source /opt/muav/muav_env.sh" >> /root/.bashrc

ENTRYPOINT ["/opt/muav/entrypoint.sh"]
CMD ["bash"]

# Desarrollo: mismos mensajes que producción + herramientas + bridge dentro (decisión 13).
# El workspace (src, build, install, log) vive en el HOST y se monta en /ws (container_run.sh dev <distro> o el
# devcontainer): se edita en el host, se compila aquí.
#   images/build.sh <distro> [dev]       (genera también .devcontainer/<distro>/devcontainer.json)
#
# Por distro, además del contrato y rosbridge:
#   noetic  Onboard-SDK (dji_osdk_ros completo en /ws), mavros, multimaster, GStreamer RTSP; PX4 v1.14.4 + Gazebo 11.
#   humble  = ~/work/px4_ros2_docker (el entorno Humble de referencia), fijado por versión: Gazebo Harmonic +
#           ros_gzharmonic, PX4 v1.15.4, Agent XRCE, PX4-gazebo-models, mavlink-router, numpy<2. Para PSDK
#           (psdk_ros2 es solo Humble) y PX4 1.15.
#   jazzy   Gazebo Harmonic + ros_gz, PX4 del contrato (devices/px4_ros2/px4.env), Agent XRCE.
# PX4 con código completo en /opt/px4/PX4-Autopilot (WITH_PX4_SIM=false para no incluirlo: varios GB, ~30 min).
ARG ROS_DISTRO=humble
ARG BASE_IMAGE=muav/msgs:${ROS_DISTRO}
FROM ${BASE_IMAGE}

ARG ROS_DISTRO
ARG DEBIAN_FRONTEND=noninteractive
ARG WITH_PX4_SIM=true
# Onboard-SDK: el mismo commit que los drones OSDK.
ARG OSDK_VERSION=118e2825a347499efb8ed253146552c5b9b10779
# Lo que px4_ros2_docker tenía por rama o sin fijar.
ARG PX4_GZ_MODELS_COMMIT=e05f4312d3f28aa621157610584a4870406cb6d3
ARG MAVLINK_ROUTER_VERSION=v4

# Qt y Gazebo (GUI) necesitan un XDG_RUNTIME_DIR propio con 0700; sin él avisan y a veces la GUI no arranca. En la
# imagen y no en container_run.sh: así lo tienen igual la terminal y el devcontainer.
ENV XDG_RUNTIME_DIR=/tmp/runtime-root
RUN mkdir -p -m 0700 /tmp/runtime-root

# Variables del entorno de desarrollo (PX4_DIR, GZ_*): las carga muav_env.sh en bash y en zsh. Nada en .bashrc.
RUN mkdir -p /opt/muav && : > /opt/muav/dev_env.sh

# Común a todas las distros
RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-${ROS_DISTRO}-desktop \
        ros-${ROS_DISTRO}-rosbridge-server \
        build-essential \
        gdb \
        tmux \
    && rm -rf /var/lib/apt/lists/*

# Por distro. ROS 2: ros-dev-tools + lo que traía px4_ros2_docker (Qt xcb para las GUIs, transporte de imagen ffmpeg,
# geographiclib, GStreamer para las cámaras de gz).
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
        apt-get install -y --no-install-recommends \
            ros-dev-tools \
            ros-${ROS_DISTRO}-ffmpeg-image-transport \
            python3-geographiclib \
            curl \
            libxcb-xinerama0 \
            libxkbcommon-x11-0 \
            libxcb-cursor-dev \
            gstreamer1.0-plugins-base \
            gstreamer1.0-plugins-good \
            gstreamer1.0-plugins-bad \
            gstreamer1.0-plugins-ugly \
            gstreamer1.0-libav \
            gstreamer1.0-gl; \
       fi \
    && rm -rf /var/lib/apt/lists/*

# noetic: Onboard-SDK + datasets de mavros (sin ellos mavros aborta al arrancar).
COPY devices/common/osdk/install_osdk.sh /tmp/install_osdk.sh
RUN if [ "$ROS_DISTRO" = noetic ]; then \
        /tmp/install_osdk.sh ${OSDK_VERSION} \
        && /opt/ros/noetic/lib/mavros/install_geographiclib_datasets.sh; \
    fi

# Gazebo ROS 2. humble: Harmonic NO es el par por defecto (ros-humble-ros-gz es Fortress): gz-harmonic y
# ros-humble-ros-gzharmonic salen del repo OSRF (verificado: ninguno está en el repo de ROS). jazzy: Harmonic es el
# par por defecto. MUAV_psdk_gz compila con Fortress o Harmonic (elige Harmonic si encuentra gz-common5).
RUN apt-get update \
    && case "$ROS_DISTRO" in \
        humble) \
            curl -fsSL https://packages.osrfoundation.org/gazebo.gpg \
                -o /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg \
            && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] https://packages.osrfoundation.org/gazebo/ubuntu-stable $(. /etc/os-release && echo $UBUNTU_CODENAME) main" \
                > /etc/apt/sources.list.d/gazebo-stable.list \
            && apt-get update \
            && apt-get install -y --no-install-recommends gz-harmonic ros-humble-ros-gzharmonic ;; \
        jazzy) apt-get install -y --no-install-recommends ros-jazzy-ros-gz ;; \
       esac \
    && rm -rf /var/lib/apt/lists/*

# Agent XRCE-DDS (ROS 2): la versión de devices/px4_ros2/agent.repos, la misma que el dron.
COPY devices/px4_ros2/agent.repos images/dev/install_agent.sh /opt/muav/px4/
RUN if [ "$ROS_DISTRO" != noetic ]; then \
        bash /opt/muav/px4/install_agent.sh "$ROS_DISTRO" /opt/muav/px4/agent.repos; \
    fi

# PX4 SITL (versión por distro: ver install_px4_sitl.sh).
COPY devices/px4_ros2/px4.env images/dev/install_px4_sitl.sh /opt/muav/px4/
RUN if [ "$WITH_PX4_SIM" = true ]; then \
        bash /opt/muav/px4/install_px4_sitl.sh "$ROS_DISTRO" /opt/muav/px4/px4.env; \
    fi

# humble, como px4_ros2_docker:
#   - numpy<2 y opencv-python<4.10 DESPUÉS de PX4 (sus requirements.txt pueden subir numpy y romper cv_bridge).
#   - PX4-gazebo-models: los mundos y modelos que usan sus tmuxinator. GZ_SIM_RESOURCE_PATH se AGREGA, no se pisa.
#   - GZ_PARTITION propia: el gz del contenedor no se mezcla con otro gz de la red.
RUN if [ "$ROS_DISTRO" = humble ]; then \
        pip3 uninstall -y numpy opencv-python || true; \
        pip3 install --no-cache-dir 'numpy<2' 'opencv-python<4.10' \
        && git clone https://github.com/PX4/PX4-gazebo-models.git /opt/px4/PX4-gazebo-models \
        && git -C /opt/px4/PX4-gazebo-models checkout -q ${PX4_GZ_MODELS_COMMIT} \
        && { echo 'export GZ_SIM_RESOURCE_PATH=/opt/px4/PX4-gazebo-models/models${GZ_SIM_RESOURCE_PATH:+:$GZ_SIM_RESOURCE_PATH}'; \
             echo 'export GZ_SIM_SERVER_CONFIG_PATH=/opt/px4/PX4-gazebo-models/server.config'; \
             echo 'export GZ_PARTITION=docker_sim_harmonic'; } >> /opt/muav/dev_env.sh; \
    fi

# mavlink-router (ROS 2, como px4_ros2_docker): reparte el MAVLink del SITL o del autopiloto (QGC, GCS, scripts).
RUN if [ "$ROS_DISTRO" != noetic ]; then \
        apt-get update \
        && apt-get install -y --no-install-recommends meson ninja-build pkg-config systemd \
        && rm -rf /var/lib/apt/lists/* \
        && git clone --branch ${MAVLINK_ROUTER_VERSION} --recurse-submodules \
            https://github.com/mavlink-router/mavlink-router.git /tmp/mavlink-router \
        && cd /tmp/mavlink-router \
        && meson setup build . \
        && ninja -C build \
        && ninja -C build install \
        && rm -rf /tmp/mavlink-router; \
    fi

# Bridge dentro (decisión 13): los mismos archivos que bridge:<distro>.
#   /opt/muav/bridge/start.sh       (noetic: MUAV_HOSTS=<drones> para el multimaster)
COPY images/bridge/start.sh images/bridge/noetic.launch images/bridge/multimaster.launch /opt/muav/bridge/
RUN chmod +x /opt/muav/bridge/start.sh

# Dependencias (apt) de lo que haya en /ws/src: devcontainer al crearse, o a mano en la terminal.
COPY images/dev/ws_rosdep.sh /opt/muav/ws_rosdep.sh
RUN chmod +x /opt/muav/ws_rosdep.sh

# Drones FALSOS para ver y probar el GCS sin hardware (ROS 1): /opt/muav/mock/mock_fleet.sh. Ver images/dev/mock/.
COPY images/dev/mock/ /opt/muav/mock/
RUN chmod +x /opt/muav/mock/*.sh /opt/muav/mock/*.py

WORKDIR /ws

FROM px4io/px4-dev-ros-noetic

# ROS Noetic reached EOL May 2025 — fix broken apt sources pointing to dead mirrors
RUN rm -f /etc/apt/sources.list.d/ros*.list && \
    apt-get update && apt-get install -y curl gnupg2 && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys AD19BAB3CBF125EA && \
    echo "deb http://snapshots.ros.org/noetic/final/ubuntu focal main" \
      > /etc/apt/sources.list.d/ros-noetic-snapshots.list

RUN apt-get update

RUN apt-get install -y nano
RUN apt-get install -y ros-noetic-rviz


RUN apt-get install -y ros-noetic-rosbridge-server

# multimaster
RUN apt-get install -y ros-noetic-fkie-master-sync
RUN apt-get install -y ros-noetic-fkie-master-discovery
# ROS SDK DJI
RUN apt-get install -y ros-noetic-nmea-comms
RUN apt-get install -y ffmpeg libavcodec-dev libswresample-dev
RUN apt-get install -y libsdl2-dev
# install opencv 3.3.X


# dependencies simple VS
RUN apt-get install -y ros-noetic-cv-bridge ros-noetic-image-transport ros-noetic-theora-image-transport
RUN apt-get install -y ros-noetic-tf2-kdl
RUN apt-get install -y ros-noetic-geodesy
RUN apt-get install -y ros-noetic-tf2-geometry-msgs
RUN apt-get install -y ros-noetic-image-view
RUN apt-get install -y ros-noetic-teleop-twist-keyboard

# install Gstreamer
RUN apt-get install -y libgstreamer-plugins-base1.0-dev libgstreamer-plugins-good1.0-dev libgstreamer-plugins-bad1.0-dev libgstrtspserver-1.0-dev gstreamer1.0-plugins-ugly gstreamer1.0-plugins-bad gstreamer1.0-rtsp
RUN apt install gstreamer1.0-rtsp

# libqt5websockets5 --- for flatbuffers
RUN apt-get -y install libqt5websockets5-dev
RUN ln -s /usr/bin/python3 /usr/bin/python

RUN apt-get install -y ros-noetic-rqt-graph

RUN apt install gazebo11 libgazebo11-dev

RUN apt update && \
    apt install -y sudo 
    
# Create workspace folder
RUN mkdir -p /app/catkin_ws/src/


# add in /root/.bashrc the source of ROS and catkin_ws

RUN /bin/bash -c 'echo -e "/opt/ros/noetic/setup.bash \n" >> ~/.bashrc ;'
RUN /bin/bash -c 'echo -e "source /app/catkin_ws/devel/setup.bash \n" >> ~/.bashrc ;'

COPY .initDev.sh /app/initDev.sh
RUN chmod +x /initDev.sh
#RUN /initDev.sh
WORKDIR /app/catkin_ws

# Load ROS environment at each run
# COPY ./ros_entrypoint.sh /
# RUN chmod 755 /ros_entrypoint.sh
# ENTRYPOINT ["/ros_entrypoint.sh"]

CMD ["bash"]
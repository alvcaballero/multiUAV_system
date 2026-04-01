mkdir -p ~/app_ros1/src/external
docker build --no-cache -t ros-noetic:l4t-r36.4.7 -f Dockerfile.ros1 . && \
docker build --no-cache -t ros-noetic-muavs:l4t-r36.4.7 -f Dockerfile.muavs .

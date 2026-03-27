#!/bin/bash
cd ~/app
git clone https://github.com/dji-sdk/Onboard-SDK.git
cd Onboard-SDK
mkdir build
cd build
cmake ..
sudo make -j7 install

cd ~/app 
git clone --recurse-submodules -j8 --branch v1.14.4  https://github.com/PX4/PX4-Autopilot.git
cd PX4-Autopilot
make px4_sitl_default gazebo-classic

cd ~/app
mkdir -p catkin_ws/src
cd catkin_ws/src
git clone --recurse-submodules -j8 --branch GimbalPitch https://github.com/alvcaballero/multiUAV_system.git
git clone https://github.com/CircusMonkey/ros_rtsp.git
git clone https://github.com/miggilcas/simple_vs.git
git clone --branch noetic https://github.com/arpoma16/grvc-utils.git
git clone https://github.com/miggilcas/Onboard-SDK-ROS.git
cd ..
catkin_make


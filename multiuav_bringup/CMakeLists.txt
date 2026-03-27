cmake_minimum_required(VERSION 2.8.3)
project(multiuav_gcs_bringup)

find_package(catkin REQUIRED COMPONENTS
  multiuav_interfaces
  rospy
  std_msgs
  std_srvs
)

catkin_package()

catkin_install_python(PROGRAMS
  scripts/uavServices.py
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

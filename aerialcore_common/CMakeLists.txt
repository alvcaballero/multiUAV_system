cmake_minimum_required(VERSION 2.8.3)
project(aerialcore_common)

add_compile_options(-std=c++11)

## Find catkin macros and libraries
find_package(catkin REQUIRED COMPONENTS
  message_generation
  sensor_msgs
)

################################################
## Declare ROS messages, services and actions ##
################################################

# Generate messages in the 'msg' folder
add_message_files(
   FILES
   BatteryState.msg
   BatteryState_melodic.msg

)


# Generate services in the 'srv' folder
add_service_files(
  FILES
  ConfigMission.srv
  finishGetFiles.srv
  finishMission.srv

)

## Generate actions in the 'action' folder
# add_action_files(
#   FILES
#   Action1.action
#   Action2.action
# )

## Generate added messages and services with any dependencies listed here
generate_messages(
  DEPENDENCIES
  sensor_msgs
  std_msgs
)


###################################
## catkin specific configuration ##
###################################
catkin_package(
  # INCLUDE_DIRS
  # LIBRARIES ${PROJECT_NAME}
  CATKIN_DEPENDS sensor_msgs std_msgs
#  DEPENDS system_lib
)

###########
## Build ##
###########

## Specify additional locations of header files
## Your package locations should be listed before other locations
# include_directories(
#   include
#   ${catkin_INCLUDE_DIRS}
# )

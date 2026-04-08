# M300 ros1 - nvidia jetson orin nano

## hardware setup:
Two options:
### OSDK Expansion Module:
[manual osdk expansion module](https://dl.djicdn.com/downloads/matrice-300/20200617/OSDK_Expansion_Module_Product_Information.pdf#page=14.28)

## software setup
## Project Structure
Workdir: `~/programing/`

| Directory     | Purpose          | repo                                   |
| ------------- | ---------------- | -------------------------------------- |
| `Onboard-SDK/`| DJI onboard sdk  | https://github.com/dji-sdk/Onboard-SDK |
| `resisto_ws/` | ROS workspace    |                                        |

## Ros workspace structure
Workdir: `~/programing/resisto_ws/src/`

| Directory         | Purpose          | repo                                                        |
| ----------------- | ---------------- | ----------------------------------------------------------- |
| `multiUAV_system` | mission messages | GimbalPitch https://github.com/alvcaballero/multiUAV_system |
| `Onboard-SDK-ROS` | Ros osdk dji     | dev https://github.com/miggilcas/Onboard-SDK-ROS            |
| `ros_rtsp`        | video streaming  | https://github.com/CircusMonkey/ros_rtsp.git                |
| `simple_vs`       | resize image     | cuda https://github.com/miggilcas/simple_vs.git             |
| `vision_opencv`   | utils image      | noetic https://github.com/ros-perception/vision_opencv.git  |


## fists stepp instal  install and test the onboard sdk and create a user 
https://developer.dji.com/cn/onboard-sdk/documentation/quick-start/quick-start.html

### inicial setup.
Userconfig.txt

Install  Offboard sdk  in:/home/nvidia/programming/Onboard-SDK/
add to .bashrc alias of simulation and real conecction to uav:
```bash
alias M300-real="/home/nvidia/programming/Onboard-SDK/utility/bin/armv8/64-bit/./MatriceSeries_ConfigTool --usb-port /dev/ttyACM0 --config-file /home/nvidia/programming/Onboard-SDK/build/bin/UserConfig.txt --power-supply on"
alias M300-sim-on="/home/nvidia/programming/Onboard-SDK/utility/bin/armv8/64-bit/./MatriceSeries_ConfigTool --usb-port /dev/ttyACM0 --config-file /home/nvidia/programming/Onboard-SDK/build/bin/UserConfig.txt --power-supply on --usb-connected-flight on --simulation on --latitude 37.1939871 --longitude -6.7032891"
```

in the launch  /Onboard-SDK-ROS/launch/dji_vehicle_node.launch"
add the  app_id  and code 


install the packages ros
configure netplan: ruta  /etc/netplan/50-cloud-init.yaml


La mejor forma es usar el rosrtcp par aenviar la camara 

configurar el host 
copiar los tmuxinator a la carpeta ~/.tmux 
# execution

```
tmuxinator start M300-RosRTCP mode=real
```
change host and verify the host in uav and gcs computer
```
nano /etc/hosts
```

#!/bin/bash
# Entrypoint de los dispositivos OSDK (M300, M210, ...). dji_vehicle_node.launch (Onboard-SDK-ROS) tiene app_id /
# enc_key / puertos escritos como <param>, sin argumentos: se reescriben al arrancar con la config REAL montada en
# /root/cfg (container_run.sh del dispositivo).
# OJO: el launch de Onboard-SDK-ROS @ d7ee4b4 trae credenciales escritas en el repo (público). Esto las pisa.
#
# Entorno: ROS (/root/catkin_ws/install en el Jetson, /opt/ros/noetic con apt) + workspace del dispositivo
# (OSDK_WS, por defecto /root/app_ws).

USER_CONFIG=/root/cfg/UserConfig_osdk.txt
OSDK_WS=${OSDK_WS:-/root/app_ws}

if [ -f /root/catkin_ws/install/setup.bash ]; then
    source /root/catkin_ws/install/setup.bash
else
    source "/opt/ros/${ROS_DISTRO:-noetic}/setup.bash"
fi
source "$OSDK_WS/devel/setup.bash"

if [ ! -f "$USER_CONFIG" ]; then
    echo "[entrypoint_osdk] ERROR: falta $USER_CONFIG" >&2
    echo "[entrypoint_osdk]   cp devices/<dispositivo>/cfg/UserConfig_osdk.txt.example .../UserConfig_osdk.txt   # y completar" >&2
    exit 1
fi

# El launch que va a usar roslaunch: con catkin_make (devel space) es el de src/.
LAUNCH_FILE="$(rospack find dji_osdk_ros)/launch/dji_vehicle_node.launch"
if [ ! -f "$LAUNCH_FILE" ]; then
    echo "[entrypoint_osdk] ERROR: no existe $LAUNCH_FILE" >&2
    exit 1
fi

# Formato DJI "clave : valor" (el mismo archivo lo usa MatriceSeries_ConfigTool).
cfg() { grep -E "^\s*$1\s*:" "$USER_CONFIG" | head -1 | cut -d: -f2- | tr -d ' \t\r\n'; }
export OSDK_APP_ID=$(cfg app_id) OSDK_APP_KEY=$(cfg app_key) OSDK_SERIAL=$(cfg device) \
       OSDK_BAUD=$(cfg baudrate) OSDK_ACM=$(cfg acm_port)

if [ -z "$OSDK_APP_ID" ] || [ -z "$OSDK_APP_KEY" ]; then
    echo "[entrypoint_osdk] ERROR: app_id o app_key vacíos en $USER_CONFIG" >&2
    exit 1
fi

# Valores por variables de entorno, NO interpolados en el código Python.
python3 - "$LAUNCH_FILE" <<'PYEOF'
import os, re, sys

path = sys.argv[1]
values = {
    "app_id": os.environ["OSDK_APP_ID"],
    "enc_key": os.environ["OSDK_APP_KEY"],
    "serial_name": os.environ.get("OSDK_SERIAL", ""),
    "baud_rate": os.environ.get("OSDK_BAUD", ""),
    "acm_name": os.environ.get("OSDK_ACM", ""),
}
with open(path) as f:
    content = f.read()
for name, value in values.items():
    if not value:
        continue
    pattern = r'(<param name="{}"[^>]*value=")[^"]*(")'.format(re.escape(name))
    content, n = re.subn(pattern, lambda m: m.group(1) + value + m.group(2), content)
    if n == 0:
        print("[entrypoint_osdk] WARN: <param name=\"{}\"> no está en {}".format(name, path), file=sys.stderr)
with open(path, "w") as f:
    f.write(content)
PYEOF

echo "[entrypoint_osdk] app_id=$OSDK_APP_ID  serial=$OSDK_SERIAL  baud=$OSDK_BAUD  acm=$OSDK_ACM  (app_key oculta)"

exec "$@"

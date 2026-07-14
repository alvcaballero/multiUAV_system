#!/bin/bash
# Entrypoint: parsea UserConfig.txt y actualiza dji_vehicle_node.launch antes de arrancar

USER_CONFIG="/root/Onboard-SDK/build/bin/UserConfig_osdk.txt"
LAUNCH_FILE="/root/app_ws/src/Onboard-SDK-ROS/launch/dji_vehicle_node.launch"

if [ ! -f "$USER_CONFIG" ]; then
    echo "[entrypoint] ERROR: credential file not found at $USER_CONFIG" >&2
    echo "[entrypoint] You must create the real config from the template first:" >&2
    echo "[entrypoint]   cp UserConfig_osdk.txt.example UserConfig_osdk.txt" >&2
    echo "[entrypoint]   # then fill in your DJI app_id / app_key" >&2
    echo "[entrypoint] and mount it into the container:" >&2
    echo "[entrypoint]   -v /path/to/UserConfig_osdk.txt:$USER_CONFIG:ro" >&2
    exit 1
fi

if [ -f "$USER_CONFIG" ]; then
    # Parsear valores del archivo (formato: "clave : valor")
    APP_ID=$(grep -E '^\s*app_id\s*:' "$USER_CONFIG" | awk -F: '{print $2}' | tr -d ' \t\r\n')
    APP_KEY=$(grep -E '^\s*app_key\s*:' "$USER_CONFIG" | awk -F: '{print $2}' | tr -d ' \t\r\n')
    SERIAL=$(grep -E '^\s*device\s*:' "$USER_CONFIG" | awk -F: '{print $2}' | tr -d ' \t\r\n')
    BAUD=$(grep -E '^\s*baudrate\s*:' "$USER_CONFIG" | awk -F: '{print $2}' | tr -d ' \t\r\n')
    ACM=$(grep -E '^\s*acm_port\s*:' "$USER_CONFIG" | awk -F: '{print $2}' | tr -d ' \t\r\n')

    echo "[entrypoint] UserConfig loaded:"
    echo "  app_id     = $APP_ID"
    echo "  serial     = $SERIAL"
    echo "  baudrate   = $BAUD"
    echo "  acm_port   = $ACM"

    if [ -f "$LAUNCH_FILE" ] && [ -n "$APP_ID" ] && [ -n "$APP_KEY" ]; then
        sed -i "s|value=\"[^\"]*\"\\(.*name=\"app_id\"\)|value=\"$APP_ID\"\1|" "$LAUNCH_FILE" 2>/dev/null || true
        sed -i "s|value=\"[^\"]*\"\\(.*name=\"enc_key\"\)|value=\"$APP_KEY\"\1|" "$LAUNCH_FILE" 2>/dev/null || true

        # Reemplazo más robusto usando python3 (evita edge-cases de sed con caracteres especiales en la key)
        python3 - <<PYEOF
import re, sys

path = "$LAUNCH_FILE"
app_id = "$APP_ID"
app_key = "$APP_KEY"
serial = "$SERIAL"
baud = "$BAUD"
acm = "$ACM"

with open(path, 'r') as f:
    content = f.read()

def replace_param(text, name, value):
    pattern = r'(<param name="{}"[^/]*value=")[^"]*(")'  .format(re.escape(name))
    return re.sub(pattern, r'\g<1>' + value + r'\2', text)

content = replace_param(content, 'app_id', app_id)
content = replace_param(content, 'enc_key', app_key)
content = replace_param(content, 'serial_name', serial)
content = replace_param(content, 'baud_rate', baud)
content = replace_param(content, 'acm_name', acm)

with open(path, 'w') as f:
    f.write(content)

print("[entrypoint] Launch file updated: " + path)
PYEOF
    else
        echo "[entrypoint] WARNING: launch file not found or UserConfig incomplete, using defaults"
    fi
fi

# Sourcear ROS y arrancar bash
source /root/app_ws/devel/setup.bash 2>/dev/null || source /root/catkin_ws/install/setup.bash
exec "$@"

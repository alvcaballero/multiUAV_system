#!/bin/bash
# Entrypoint PSDK: inyecta credenciales DJI en psdk_ros2 via variables de entorno

USER_CONFIG="/root/UserConfig_psdk.txt"

if [ ! -f "$USER_CONFIG" ]; then
    echo "[entrypoint_psdk] ERROR: credential file not found at $USER_CONFIG" >&2
    echo "[entrypoint_psdk] You must create the real config from the template first:" >&2
    echo "[entrypoint_psdk]   cp UserConfig_psdk.txt.example UserConfig_psdk.txt" >&2
    echo "[entrypoint_psdk]   # then fill in your DJI app_id / app_key / app_license" >&2
    echo "[entrypoint_psdk] and mount it into the container:" >&2
    echo "[entrypoint_psdk]   -v /path/to/UserConfig_psdk.txt:$USER_CONFIG:ro" >&2
    exit 1
fi

if [ -f "$USER_CONFIG" ]; then
    APP_NAME=$(grep -E '^\s*app_name\s*:' "$USER_CONFIG" | awk -F: '{print $2}' | tr -d ' \t\r\n')
    APP_ID=$(grep -E '^\s*app_id\s*:' "$USER_CONFIG" | awk -F: '{print $2}' | tr -d ' \t\r\n')
    APP_KEY=$(grep -E '^\s*app_key\s*:' "$USER_CONFIG" | awk -F: '{print $2}' | tr -d ' \t\r\n')
    APP_LICENSE=$(grep -E '^\s*app_license\s*:' "$USER_CONFIG" | awk -F: '{print $2}' | tr -d ' \t\r\n')
    DEVELOPER_ACCOUNT=$(grep -E '^\s*developer_account\s*:' "$USER_CONFIG" | awk -F: '{print $2}' | tr -d ' \t\r\n')
    BAUD=$(grep -E '^\s*baudrate\s*:' "$USER_CONFIG" | awk -F: '{print $2}' | tr -d ' \t\r\n')

    export PSDK_APP_NAME="${APP_NAME:-$PSDK_APP_NAME}"
    export PSDK_APP_ID="${APP_ID:-$PSDK_APP_ID}"
    export PSDK_APP_KEY="${APP_KEY:-$PSDK_APP_KEY}"
    export PSDK_APP_LICENSE="${APP_LICENSE:-$PSDK_APP_LICENSE}"
    export PSDK_DEVELOPER_ACCOUNT="${DEVELOPER_ACCOUNT:-$PSDK_DEVELOPER_ACCOUNT}"
    export PSDK_BAUD_RATE="${BAUD:-$PSDK_BAUD_RATE}"

    echo "[entrypoint_psdk] UserConfig loaded:"
    echo "  app_name          = $PSDK_APP_NAME"
    echo "  app_id            = $PSDK_APP_ID"
    echo "  developer_account = $PSDK_DEVELOPER_ACCOUNT"
    echo "  baudrate          = $PSDK_BAUD_RATE"
fi

source /opt/ros/humble/setup.bash
source /root/psdk_ws/install/setup.bash 2>/dev/null || echo "[entrypoint_psdk] WARNING: workspace not built yet"

exec "$@"

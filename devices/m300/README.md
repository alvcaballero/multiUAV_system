# M300 RTK — Jetson Orin Nano (L4T r36.4, arm64)

Dos perfiles, cada uno atado a UNA distro, con un `.repos` por distro (igual que el contrato `images/msgs/`):

| Perfil | Distro | `.repos` | Estado |
|---|---|---|---|
| PSDK | ROS 2 Humble | `humble.repos` | Aquí |
| OSDK | ROS 1 Noetic (vía `jetson-containers`) | `noetic.repos` | R2; hoy en `multiuav_bringup/devices/M300` |

**Sin Jazzy**: `psdk_ros2` está probado solo en Humble, y L4T r36.4 es Ubuntu 22.04, mientras que Jazzy solo tiene
apt para 24.04.

## Qué hay aquí

| Archivo | Para qué |
|---|---|
| `Dockerfile.opencv` → `Dockerfile.ros2` → `Dockerfile.psdk` | Cadena de imágenes: OpenCV CUDA → ROS 2 Humble → PSDK + workspace |
| `humble.repos` | Paquetes propios del M300 en Humble (`MUAV_psdk_offboard`). Van junto al contrato `images/msgs/humble.repos` |
| `cfg/*.example` | Plantillas de config. Los reales (`cfg/psdk_params.yaml`, `cfg/link_config.json`) están gitignored |
| `container_build.sh` / `container_run.sh` | Construir y arrancar, EN el Jetson |
| `set_usb_mode.sh` | Cambia el gadget USB del Jetson entre OSDK (CDC-ACM) y PSDK (USB bulk) |
| `tmuxinator.yml` | Arranque a bordo: wrapper PSDK, streaming, RTSP, notifier, downloader |

El workspace de la imagen (`/root/psdk_ws`) toma las versiones del contrato + `humble.repos`, pero compila SOLO
`--packages-up-to psdk_wrapper muav_psdk_offboard`: entran los mensajes que piden sus `package.xml`
(`psdk_interfaces`, `muav_gcs_interfaces`), en los mismos commits que `bridge:humble`. `px4_msgs` no se compila.
`psdk_wrapper` sale del mismo checkout del fork que `psdk_interfaces` (nada por apt).

## Instalación a bordo (una vez)

1. App en <https://developer.dji.com/user/apps/> registrada como **Payload SDK** para el M300.
2. Clonar este repo en el Jetson (por defecto el tmuxinator lo busca en `~/multiUAV_system`).
3. Credenciales, **nunca a git**:
   ```bash
   cd devices/m300/cfg
   cp psdk_params.yaml.example psdk_params.yaml   # app_id, app_key, app_license, developer_account
   cp link_config.json.example link_config.json   # puertos UART / USB bulk si difieren
   git status                                      # NO deben aparecer
   ```
   `psdk_wrapper` lee las credenciales de **sus parámetros ROS** (`psdk_params.yaml`), no de variables de entorno.
4. Modo USB PSDK (requisitos de la primera vez en la cabecera de `set_usb_mode.sh`):
   ```bash
   sudo devices/m300/set_usb_mode.sh psdk --now
   ```
5. Imágenes (horas en el Orin Nano; OpenCV CUDA es lo lento):
   ```bash
   devices/m300/container_build.sh            # opencv → ros2 → psdk
   devices/m300/container_build.sh psdk       # solo rehacer el workspace (p. ej. tras cambiar un .repos)
   ```

## Uso

```bash
tmuxinator start -p devices/m300/tmuxinator.yml ns=uav_16
# o a mano:
devices/m300/container_run.sh [restart] [--no-bulk]
ros2 launch psdk_wrapper wrapper.launch.py namespace:=uav_16 \
  psdk_params_file_path:=/root/cfg/psdk_params.yaml link_config_file_path:=/root/cfg/link_config.json
```

Desarrollar a bordo sin reconstruir: `M300_DEV_SRC=~/m300_src devices/m300/container_run.sh restart` monta ese
directorio en `/root/psdk_ws/src/external`; se compila dentro con `colcon build`.

## Verificación con el GCS

En el GCS: `images/build.sh humble` y `./container_run.sh bridge humble`. Con el M300 en la misma red (misma
`ROS_DOMAIN_ID`), la interfaz `dji_M300_PSDK` del GCS debe recibir telemetría (`psdk_interfaces/msg/*`).

# M300 RTK — Jetson Orin Nano (L4T r36.4, arm64)

Dos perfiles, cada uno atado a UNA distro, con un `.repos` por distro (igual que el contrato `images/msgs/`).
Son **excluyentes**: el gadget USB del Jetson está en modo OSDK (CDC-ACM) o PSDK (USB bulk), ver `set_usb_mode.sh`.

| Perfil | Distro | Cadena de imágenes | `.repos` propio | Contrato |
|---|---|---|---|---|
| PSDK | ROS 2 Humble | `opencv → ros2 → psdk` | `humble.repos` | `images/msgs/humble.repos` |
| OSDK | ROS 1 Noetic (desde fuentes) | `opencv → ros1 → osdk` | `noetic.repos` | `images/msgs/noetic.repos` |

- **Sin Jazzy**: `psdk_ros2` está probado solo en Humble, y L4T r36.4 es Ubuntu 22.04, mientras que Jazzy solo tiene
  apt para 24.04.
- **Noetic desde fuentes**: tampoco tiene apt para 22.04. `Dockerfile.ros1` compila ROS con los repos de
  `noetic_ros.repos`, todos fijados (antes eran `git clone`, varios por rama).

## Qué hay aquí

| Archivo | Para qué |
|---|---|
| `Dockerfile.opencv` | OpenCV CUDA (base común de los dos perfiles) |
| `Dockerfile.ros2` → `Dockerfile.psdk` | PSDK: ROS 2 Humble por apt → PSDK + workspace |
| `Dockerfile.ros1` → `Dockerfile.osdk` | OSDK: ROS 1 Noetic desde fuentes → Onboard-SDK + workspace |
| `humble.repos` / `noetic.repos` | Paquetes propios del M300 en cada distro. Van junto al contrato de esa distro |
| `noetic_ros.repos` | ROS 1 Noetic base, desde fuentes (lo importa `Dockerfile.ros1`) |
| `cfg/*.example` | Plantillas de config con credenciales. Los reales están gitignored |
| `config/ros_rtsp_stream_setup.yaml` | Streams RTSP del perfil OSDK (se monta encima del de `ros_rtsp`) |
| `container_build.sh` / `container_run.sh` | Construir y arrancar, EN el Jetson |
| `set_usb_mode.sh` | Cambia el gadget USB del Jetson entre OSDK y PSDK |
| `tmuxinator_psdk.yml` / `tmuxinator_osdk.yml` | Arranque a bordo de cada perfil |

Los dos workspaces compilan SOLO lo que piden los paquetes del M300, con las versiones del contrato:

- **PSDK** (`/root/psdk_ws`): `--packages-up-to psdk_wrapper muav_psdk_offboard`. Entran `psdk_interfaces` y
  `muav_gcs_interfaces`; `px4_msgs` no. `psdk_wrapper` sale del mismo checkout del fork que `psdk_interfaces`.
- **OSDK** (`/root/app_ws`): `--only-pkg-with-deps onboard_dji simple_vs ros_rtsp fkie_master_discovery
  fkie_master_sync`. Entran `dji_osdk_ros` COMPLETO (el bridge lo compila solo-interfaces) y `aerialcore_common`.
  El Onboard-SDK se instala en `/usr/local`, fijado en `Dockerfile.osdk`.

## Instalación a bordo (una vez)

1. App en <https://developer.dji.com/user/apps/>: **Payload SDK** para PSDK y/o **Onboard SDK** para OSDK.
2. Clonar este repo en el Jetson (por defecto los tmuxinator lo buscan en `~/multiUAV_system`).
3. Credenciales, **nunca a git**:
   ```bash
   cd devices/m300/cfg
   cp psdk_params.yaml.example psdk_params.yaml         # PSDK: app_id, app_key, app_license, developer_account
   cp link_config.json.example link_config.json         # PSDK: puertos UART / USB bulk si difieren
   cp UserConfig_osdk.txt.example UserConfig_osdk.txt   # OSDK: app_id, app_key, puertos
   git status                                            # NO deben aparecer
   ```
   - PSDK: `psdk_wrapper` lee las credenciales de **sus parámetros ROS** (`psdk_params.yaml`), no de variables de
     entorno.
   - OSDK: `dji_vehicle_node.launch` no recibe argumentos, así que `entrypoint_osdk.sh` reescribe sus `<param>` al
     arrancar con `UserConfig_osdk.txt`. El mismo archivo lo usa `MatriceSeries_ConfigTool` (alias `M300-real` y
     `M300-sim-on`).
4. Modo USB (requisitos de la primera vez en la cabecera de `set_usb_mode.sh`):
   ```bash
   sudo devices/m300/set_usb_mode.sh psdk --now      # o osdk
   ```
5. Imágenes (horas en el Orin Nano; OpenCV CUDA es lo lento):
   ```bash
   devices/m300/container_build.sh               # todo: opencv → ros2 → psdk → ros1 → osdk
   devices/m300/container_build.sh psdk          # solo rehacer el workspace PSDK (p. ej. tras cambiar un .repos)
   devices/m300/container_build.sh osdk          # solo rehacer el workspace OSDK
   ```

## Uso

```bash
# PSDK (ROS 2)
tmuxinator start -p devices/m300/tmuxinator_psdk.yml ns=uav_16
# OSDK (ROS 1). MUAV_HOSTS = el/los GCS para el multimaster
MUAV_HOSTS=<gcs> tmuxinator start -p devices/m300/tmuxinator_osdk.yml ns=uav_14 mode=real

# a mano
devices/m300/container_run.sh psdk [restart] [--no-bulk]
devices/m300/container_run.sh osdk [restart]
```

Desarrollar a bordo sin reconstruir: `M300_DEV_SRC=~/m300_src devices/m300/container_run.sh <psdk|osdk> restart`
monta ese directorio en `<workspace>/src/external`; se compila dentro (`colcon build` / `catkin_make`).

## Verificación con el GCS

- **PSDK**: en el GCS, `images/build.sh humble` y `./container_run.sh bridge humble`. Con el M300 en la misma red
  (misma `ROS_DOMAIN_ID`), la interfaz `dji_M300_PSDK` debe recibir telemetría (`psdk_interfaces/msg/*`).
- **OSDK**: en el GCS, `images/build.sh noetic` y `MUAV_HOSTS=<host del M300> ./container_run.sh bridge noetic`. Cada
  lado lista al OTRO en `MUAV_HOSTS`, y los nombres tienen que resolverse en el `/etc/hosts` de los dos. La interfaz
  `dji_M300` debe recibir telemetría (`dji_osdk_ros/*`).

# M300 RTK: Jetson Orin Nano (L4T r36.4, arm64)

Dos perfiles, **excluyentes**: el USB del Jetson está en modo OSDK o en modo PSDK (`host/set_usb_mode.sh`), y cada
uno usa su contenedor y su distro.

| Perfil | Distro | Para qué | Guía de puesta en marcha |
|---|---|---|---|
| **PSDK** | ROS 2 Humble | Telemetría, misiones, cámara (USB bulk) y descarga de archivos; interfaz del GCS `dji_M300_PSDK` | [`psdk/SETUP.md`](psdk/SETUP.md) |
| **OSDK** | ROS 1 Noetic | Misiones con `onboard_dji` y vídeo por RTSP; interfaz del GCS `dji_M300` | [`osdk/SETUP.md`](osdk/SETUP.md) |

Hardware común: **Jetson Orin Nano** como computadora de a bordo, conectada al **puerto OSDK** del M300 con el
**OSDK Expansion Module** (o el **E-Port Development Kit**). El detalle de cables, alimentación y modos está en
cada guía.

## Estructura

```
devices/m300/
├── README.md              este índice
├── container_build.sh     construir (EN el Jetson): all | opencv | ros2 | psdk | ros1 | osdk
├── container_run.sh       arrancar: psdk [restart] [--no-bulk] | osdk [restart]
├── base/
│   └── Dockerfile.opencv  OpenCV CUDA: base común de los dos perfiles (lo más lento: horas)
├── psdk/                  perfil PSDK (ROS 2 Humble)
│   ├── SETUP.md           hardware + puesta en marcha
│   ├── Dockerfile.ros2    ROS 2 Humble por apt sobre la base
│   ├── Dockerfile         PSDK + workspace (contrato images/msgs/humble.repos + humble.repos)
│   ├── humble.repos       paquetes propios (MUAV_psdk_offboard)
│   ├── entrypoint.sh      verifica que la config real esté montada
│   └── tmuxinator.yml     arranque a bordo
├── osdk/                  perfil OSDK (ROS 1 Noetic)
│   ├── SETUP.md           hardware + puesta en marcha
│   ├── Dockerfile.ros1    ROS 1 Noetic DESDE FUENTES (no hay apt para Ubuntu 22.04)
│   ├── ros1.repos         los repos de ROS 1 que compila Dockerfile.ros1, fijados
│   ├── Dockerfile         Onboard-SDK + workspace (contrato images/msgs/noetic.repos + noetic.repos)
│   ├── noetic.repos       paquetes propios (onboard_dji, simple_vs, ros_rtsp, multimaster)
│   ├── ros_rtsp_stream_setup.yaml   streams RTSP (se monta encima del de ros_rtsp)
│   └── tmuxinator.yml     arranque a bordo
├── host/                  corre en el JETSON, fuera de los contenedores
│   ├── set_usb_mode.sh    cambia el USB del Jetson entre OSDK y PSDK
│   └── netplan.yaml.example   red del Jetson
└── cfg/                   credenciales DJI: solo los .example van a git
```

Cadenas de imágenes (todas con tag `:l4t-r36.4.0`):

```
base/Dockerfile.opencv → opencv-cuda ─┬─► psdk/Dockerfile.ros2 → ros-humble ─► psdk/Dockerfile → ros-humble-psdk
                                      └─► osdk/Dockerfile.ros1 → ros-noetic ─► osdk/Dockerfile → ros-noetic-osdk
```

## Por qué así

- **Sin Jazzy**: `psdk_ros2` está probado solo en Humble, y L4T r36.4 es Ubuntu 22.04 (Jazzy solo tiene apt en 24.04).
- **Noetic desde fuentes**: tampoco tiene apt para 22.04. `osdk/Dockerfile.ros1` compila ROS con `osdk/ros1.repos`.
- Cada workspace compila SOLO lo que piden los paquetes del M300, con las versiones del contrato:
  - **PSDK** (`/root/psdk_ws`): `--packages-up-to psdk_wrapper muav_psdk_offboard`. Entran `psdk_interfaces` y
    `muav_gcs_interfaces`; `px4_msgs` no. `psdk_wrapper` sale del mismo checkout del fork que `psdk_interfaces`.
  - **OSDK** (`/root/app_ws`): `--only-pkg-with-deps onboard_dji simple_vs ros_rtsp fkie_master_discovery
    fkie_master_sync`. Entra `dji_osdk_ros` COMPLETO (el bridge lo compila solo-interfaces). El Onboard-SDK queda en
    `/usr/local`, fijado en `osdk/Dockerfile` (`ARG OSDK_VERSION`, lo instala `devices/common/osdk/install_osdk.sh`).

## Desarrollar a bordo sin reconstruir

`M300_DEV_SRC=~/m300_src devices/m300/container_run.sh <psdk|osdk> restart` monta ese directorio en
`<workspace>/src/external`; se compila dentro (`colcon build` / `catkin_make`).

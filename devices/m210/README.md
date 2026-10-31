# M210 — Raspberry Pi (arm64, sin GPU)

Perfil **OSDK**, ROS 1 **Noetic**. Sin Melodic: todos los M210 están en Noetic (confirmado 2026-10-31).

Antes corría **nativo** en la Pi. Ahora va en contenedor, sobre la misma `muav/base:noetic` del GCS: la Pi tiene
Ubuntu 20.04 y Noetic tiene apt para arm64, así que no hace falta compilar ROS desde fuentes como en el Jetson del M300.

## Qué hay aquí

| Archivo | Para qué |
|---|---|
| `Dockerfile` | `muav/base:noetic` → Onboard-SDK + workspace (contrato + `noetic.repos`) |
| `noetic.repos` | Paquetes propios: `onboard_dji` (rama `M210`), `simple_vs` (`main`, sin CUDA), `ros_rtsp` |
| `cfg/UserConfig_osdk.txt.example` | Plantilla de credenciales DJI. El real está gitignored |
| `config/ros_rtsp_stream_setup.yaml` | Streams RTSP. **Derivado del M300, a verificar** con el de la Pi |
| `container_build.sh` / `container_run.sh` | Construir y arrancar, EN la Pi |
| `tmuxinator.yml` | Arranque a bordo: roscore, ConfigTool, misión, multimaster, resize, RTSP |

Lo compartido con el M300 OSDK está en `devices/common/osdk/`: `install_osdk.sh` (Onboard-SDK fijado) y
`entrypoint_osdk.sh` (inyecta las credenciales en `dji_vehicle_node.launch`). El multimaster es
`images/bridge/multimaster.launch`, el mismo que usa `bridge:noetic`.

El workspace compila SOLO `--only-pkg-with-deps onboard_dji simple_vs ros_rtsp`: entran `dji_osdk_ros` COMPLETO y
`aerialcore_common` del contrato. El multimaster va por apt (1.3.2, como el bridge).

## Instalación a bordo (una vez)

1. Docker en la Pi, y este repo clonado (por defecto el tmuxinator lo busca en `~/multiUAV_system`).
2. Credenciales, **nunca a git**:
   ```bash
   cp devices/m210/cfg/UserConfig_osdk.txt.example devices/m210/cfg/UserConfig_osdk.txt   # app_id, app_key, puertos
   git status                                                                              # NO debe aparecer
   ```
3. Imágenes:
   ```bash
   images/build.sh noetic base
   devices/m210/container_build.sh
   ```
4. Revisar `config/ros_rtsp_stream_setup.yaml` contra la config real de la Pi.

## Uso

```bash
MUAV_HOSTS=<gcs> tmuxinator start -p devices/m210/tmuxinator.yml id=2 mode=real
# a mano
MUAV_HOSTS=<gcs> devices/m210/container_run.sh [restart]
```

`id` es el **número** del dron: `atlas.launch` y `video_resize.launch` arman el namespace como `uav_<id>`.

## Verificación con el GCS

En el GCS: `images/build.sh noetic` y `MUAV_HOSTS=<host de la Pi> ./container_run.sh bridge noetic`. Cada lado
lista al OTRO en `MUAV_HOSTS`, y los nombres tienen que resolverse en el `/etc/hosts` de los dos. La interfaz
`dji_M210_noetic` debe recibir telemetría (`dji_osdk_ros/*`).

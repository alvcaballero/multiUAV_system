# VTOL — PX4 por mavros, Raspberry Pi (arm64, sin GPU)

**Conexión de hardware y puesta en marcha paso a paso: [`SETUP.md`](SETUP.md).**

ROS 1 **Noetic**. Es el dispositivo `px4_mavros` del plan. Antes corría **nativo** en la Pi. Ahora va en contenedor
sobre la misma `muav/base:noetic` del GCS (multi-arch, apt de Noetic para Ubuntu 20.04 arm64).

## Qué hay aquí

| Archivo | Para qué |
|---|---|
| `Dockerfile` | `muav/base:noetic` → workspace (contrato + `noetic.repos`) + mavros + GStreamer + multimaster |
| `noetic.repos` | `onboard_px4` (`main`), `grvc-ual` (`px4_bringup`), `grvc-utils` del fork arpoma16 (`mission_lib`) |
| `container_build.sh` / `container_run.sh` | Construir y arrancar, EN la Pi |
| `tmuxinator.yml` | Arranque a bordo: roscore, misión (mavros), multimaster, mediamtx, cámara |

Decisiones (2026-10-31):

- **`onboard_px4` en `main`, NO en `feature/wirispro`.** Esa rama depende de `wirispro_manager`, cuyo repo
  (`miggilcas/wirispro_manager`) es privado o no existe: no se puede clonar en el build. **El VTOL pierde el servicio
  de la cámara WIRIS Pro** hasta que ese repo sea accesible.
- **`px4_bringup` de `grvc-ual` (rama `noetic`).** Ningún script viejo lo instalaba: estaba a mano en el dron.
- **Se compila SOLO `onboard_px4 px4_bringup` y sus dependencias** (`mission_lib`, `aerialcore_common`). rosdep solo
  sobre esos paquetes y con `--skip-keys gazebo_ros`: `px4_bringup` lo pide para el modo `sitl`, y `atlas.launch`
  usa `mode=custom`. Así Gazebo no se instala en la Pi.
- **mediamtx fijado por digest** (índice multi-arch con `linux/arm64`). El GCS usa `bluenviron/mediamtx` sin tag.

Pendiente, fuera de este repo: `atlas.launch` tiene escritos `fcu_url` (`serial:///dev/ttyUSB0:57600`) y
`gcs_url` (`udp://@192.168.0.123:14550`) sin argumentos: para otro puerto u otro GCS hay que cambiar `onboard_px4`.

## Instalación a bordo (una vez)

1. Docker en la Pi, y este repo clonado (por defecto el tmuxinator lo busca en `~/multiUAV_system`).
2. Imágenes:
   ```bash
   images/build.sh noetic base
   devices/vtol/container_build.sh
   ```

PX4 no usa credenciales: no hay `cfg/`.

## Uso

```bash
MUAV_HOSTS=<gcs> tmuxinator start -p devices/vtol/tmuxinator.yml id=3 cam=/dev/video5
# a mano
MUAV_HOSTS=<gcs> devices/vtol/container_run.sh [restart]
```

## Verificación con el GCS

En el GCS: `images/build.sh noetic` y `MUAV_HOSTS=<host de la Pi> ./container_run.sh bridge noetic`. Cada lado
lista al OTRO en `MUAV_HOSTS`, y los nombres tienen que resolverse en el `/etc/hosts` de los dos. La interfaz
`px4_mavros` debe recibir telemetría. El vídeo se ve en `rtsp://<pi>:8554/video0`.

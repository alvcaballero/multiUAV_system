# VTOL: PX4 por mavros (ROS 1 Noetic), conexión y puesta en marcha

Guía para dejar el VTOL operando con `onboard_px4` (mavros) desde una Raspberry Pi, con cámara por RTSP. Orden:
hardware → firmware (parámetros) → host → software → arranque → verificación.

Fuentes: `devices/vtol/` (Dockerfile, tmuxinator, README) y `onboard_px4/launch/atlas.launch` (fijado en
`noetic.repos`). Lo marcado **⚠ A COMPLETAR** falta relevarlo en el dron.

## 1. Materiales

| Pieza | Nota |
|---|---|
| VTOL con PX4 | ⚠ A COMPLETAR: autopiloto y versión de firmware |
| Raspberry Pi | Ubuntu 20.04 arm64. ⚠ A COMPLETAR: modelo |
| Adaptador USB-UART | A un puerto TELEM del autopiloto. ⚠ A COMPLETAR: modelo y nivel lógico |
| Cámara USB | Se ve como `/dev/videoN` (por defecto el tmuxinator usa `/dev/video5`). ⚠ A COMPLETAR: modelo |
| Alimentación de la Pi | ⚠ A COMPLETAR: desde qué salida y con qué regulador a 5 V |

## 2. Conexión

```
Autopiloto TELEM (TX, RX, GND) ── USB-UART ──USB──► Pi  → /dev/ttyUSB0   57600 baudios (mavros)
Cámara ─────────────────────────────────USB──► Pi  → /dev/videoN    v4l2 → H.264 → RTSP
```

`atlas.launch` tiene **escritos** `fcu_url` (`serial:///dev/ttyUSB0:57600`) y `gcs_url`
(`udp://@192.168.0.123:14550`), sin argumentos: el adaptador TIENE que quedar en `ttyUSB0`, y para otro puerto u otro
GCS hay que cambiar `onboard_px4` (pendiente en el plan, "Fuera de este repo").

## 3. Firmware: parámetros (QGroundControl, una vez)

| Parámetro | Valor | Para qué |
|---|---|---|
| `MAV_<n>_CONFIG` | el TELEM conectado a la Pi | Instancia MAVLink en ese puerto |
| `SER_TEL<m>_BAUD` | 57600 | El baudrate de `fcu_url` |

⚠ A COMPLETAR: qué instancia y qué TELEM se usan en este dron.

## 4. Host: la Raspberry Pi (una vez)

1. Docker y este repo en `~/multiUAV_system`.
2. Red con el GCS. ⚠ A COMPLETAR: IP fija y netplan (el VTOL no tiene `host/netplan.yaml.example`).
3. Hora desde el GCS (la Pi no tiene RTC): `sudo devices/common/boot/install.sh`.
4. Nombres de host para el multimaster: el del GCS en el `/etc/hosts` de la Pi, y el de la Pi en el del GCS.

## 5. Software

```bash
images/build.sh noetic base       # en la Pi (multi-arch)
devices/vtol/container_build.sh
```

PX4 no usa credenciales: no hay `cfg/`.

## 6. Arranque

```bash
MUAV_HOSTS=<gcs> tmuxinator start -p devices/vtol/tmuxinator.yml id=3 cam=/dev/video5     # -h: parámetros
```

`id` es el **número** del dron: el namespace queda `uav_<id>`. Paneles: `roscore`, `main` (`atlas.launch`: mavros +
`px4_mission_node`), `multimaster`, `server` (mediamtx en el host) y `video-stream` (cámara → `rtsp://<pi>:8554/video0`).
La cámara cambia de número entre arranques: `v4l2-ctl --list-devices` y pasar `cam=`.

A mano: `MUAV_HOSTS=<gcs> devices/vtol/container_run.sh [restart]`.

## 7. Verificación

- Dentro del contenedor: `rostopic list | grep mavros/state` y un `rostopic echo -n1` de ese topic muestra
  `connected: True`.
- En el GCS: `images/build.sh noetic` y `MUAV_HOSTS=<host de la Pi> ./container_run.sh bridge noetic`. La interfaz
  `px4_mavros` recibe telemetría y el vídeo se ve en `rtsp://<pi>:8554/video0`.

## 8. Problemas comunes

| Síntoma | Causa probable |
|---|---|
| mavros `connected: False` | Baudrate distinto de 57600, adaptador en otro `ttyUSB`, o MAVLink sin habilitar en ese TELEM |
| Sin vídeo | Otra `/dev/videoN`: pasar `cam=` |
| El multimaster no engancha | `/etc/hosts`, o varias interfaces: `export ROS_IP=<ip de la Pi>` |
| Sin servicio de la cámara WIRIS Pro | Conocido: `onboard_px4` va en `main` porque `wirispro_manager` no es accesible (ver README) |

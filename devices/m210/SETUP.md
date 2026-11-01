# M210 V2 + OSDK (ROS 1 Noetic): conexión y puesta en marcha

Guía para dejar un M210 V2 operando con `onboard_dji` desde una Raspberry Pi. Se hace en este orden: hardware → dron →
host (Pi) → software → arranque → verificación.

Fuentes: [DJI: device connection](https://developer.dji.com/onboard-sdk/documentation/quickstart/device-connection.html)
(M210 V2), [DJI: M210 aircraft checklist](https://developer.dji.com/onboard-sdk/documentation/M210-Docs/aircraft-checklist.html).
Lo marcado **⚠ A COMPLETAR** o **⚠ A CONFIRMAR** falta relevarlo en el dron.

**Sin OSDK Expansion Module** (ese es solo del M300): la Pi va **por cable directo a los puertos del M210**, UART y
USB (confirmado por el equipo, 2026-11-01; coincide con la documentación de DJI para el M210 V2).

## 1. Materiales

| Pieza | Nota |
|---|---|
| M210 V2 (o M210 RTK V2) | Compatible con Onboard SDK 3.9 o posterior (DJI) |
| Raspberry Pi | Ubuntu 20.04 arm64. ⚠ A COMPLETAR: modelo |
| Cable USB-TTL **FT232** | Al puerto UART trasero. **3,3 V** (DJI: el serial del M210 V2 es de 3,3 V) |
| Cable USB doble | Al puerto USB del dron: ConfigTool y Advanced Sensing |
| Step-down | La salida de potencia del dron es de **18–26 V, 2 A** (XT30, sin regular). ⚠ A COMPLETAR: step-down a 5 V para la Pi |

## 2. Conexión

```
M210 V2  ├─ UART trasero (TX, RX, GND · 3,3 V) ── FT232 ──USB──► Pi  → /dev/ttyUSB0   921600 baudios
         ├─ USB ──────────────── cable USB doble ─────────────► Pi  → /dev/ttyACM0   ConfigTool
         └─ XT30 · 18–26 V, 2 A ── step-down ⚠ ──────────────► alimentación de la Pi
```

- DJI pide usar **el USB y el serial a la vez**.
- **No alimentes la computadora desde el pin VCC** del puerto: puede dañar el dron o la computadora (DJI).
- La salida XT30 se enciende con el ConfigTool (`--power-supply on`, lo hacen los alias `M210-real` y `M210-sim-on`),
  y el estado se mantiene entre reinicios.
- Si la computadora dispara la **protección de sobrecorriente** (pico de 24 V / 5 A, o reinicios frecuentes):
  desconectar el XT30, revisar el consumo y volver a conectar (DJI).
- Opcional, solo M210 RTK V2: sincronización de hora conectando SYNC a los pines PPS y GND traseros.

## 3. Configuración del dron (una vez)

1. App **Onboard SDK** en <https://developer.dji.com/user/apps/> (`app_id`, `app_key`).
2. **DJI Assistant 2**: baudrate del puerto OSDK en 921600, el de `cfg/UserConfig_osdk.txt`.
   ⚠ A CONFIRMAR: si la versión de Assistant 2 del M210 pide además habilitar el control por API.

## 4. Host: la Raspberry Pi (una vez)

1. Docker y este repo en `~/multiUAV_system`.
2. Red: `devices/m210/host/netplan.yaml.example` → `/etc/netplan/50-cloud-init.yaml` (completar las contraseñas
   WiFi) y `sudo netplan apply`. Deja la IP fija `10.42.0.43`.
3. Hora desde el GCS (la Pi no tiene RTC): `sudo devices/common/boot/install.sh` (`GCS_HOST` en `/etc/muav/boot.env`).
4. Nombres de host para el multimaster: el del GCS en el `/etc/hosts` de la Pi, y el de la Pi en el del GCS.

## 5. Software

```bash
cp devices/m210/cfg/UserConfig_osdk.txt.example devices/m210/cfg/UserConfig_osdk.txt   # app_id, app_key, puertos
git status                                     # NO debe aparecer
images/build.sh noetic base                    # en la Pi (multi-arch)
devices/m210/container_build.sh
```

## 6. Arranque

```bash
MUAV_HOSTS=<gcs> tmuxinator start -p devices/m210/tmuxinator.yml id=2 mode=real    # -h: parámetros
```

> **Sin `mode=real` arranca en SIMULACIÓN** (`M210-sim-on`).

`id` es el **número** del dron: el namespace queda `uav_<id>`. Paneles: `roscore`, `config` (ConfigTool), `mission`
(`onboard_dji atlas.launch`), `multimaster`, `resize` (`simple_vs`) y `rtsp` (`ros_rtsp`, streams de
`config/ros_rtsp_stream_setup.yaml`). A mano: `MUAV_HOSTS=<gcs> devices/m210/container_run.sh [restart]`.

## 7. Verificación

En el GCS: `images/build.sh noetic` y `MUAV_HOSTS=<host de la Pi> ./container_run.sh bridge noetic`. La interfaz
`dji_M210_noetic` recibe telemetría (`dji_osdk_ros/*`).

## 8. Problemas comunes

| Síntoma | Causa probable |
|---|---|
| Ni `ttyUSB0` ni `ttyACM0` | Cables sueltos (`container_run.sh` lo avisa) |
| La Pi se apaga sola | Protección de corriente del dron: revisar consumo y step-down |
| El multimaster no engancha | `/etc/hosts`, o varias interfaces: `export ROS_IP=<ip de la Pi>` |
| "Vuela" pero no se mueve | Arrancó en simulación: falta `mode=real` |

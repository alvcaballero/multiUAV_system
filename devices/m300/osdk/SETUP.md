# M300 + OSDK (ROS 1 Noetic): conexión y puesta en marcha

Guía para dejar un M300 RTK operando con `onboard_dji` (Onboard SDK) desde un Jetson Orin Nano. Se hace en este
orden: hardware → dron (DJI Assistant 2) → host (Jetson) → software → arranque → verificación.

Fuentes: [DJI: device connection](https://developer.dji.com/onboard-sdk/documentation/quickstart/device-connection.html),
[manual del OSDK Expansion Module](https://dl.djicdn.com/downloads/matrice-300/20200617/OSDK_Expansion_Module_Product_Information.pdf#page=14.28)
(pinout, p. 14), `multiuav_bringup/devices/M300/Readme.md` (en la historia de git: `906bfb1^`).
Lo marcado **⚠ A COMPLETAR** falta relevarlo en el dron.

## 1. Materiales

| Pieza | Nota |
|---|---|
| M300 RTK | Puerto **OSDK** (el OSDK del M300 necesita Onboard SDK 4.0 o posterior) |
| Jetson Orin Nano | L4T r36.4 (Ubuntu 22.04) |
| **OSDK Expansion Module** | El mismo módulo que en PSDK. *O* el E-Port Development Kit: ⚠ A COMPLETAR, sin probar con OSDK acá |
| Adaptador USB-UART (FTDI) | **3,3 V** (DJI: el serial del M300 y del módulo es de 3,3 V) |
| Cable USB | Del USB 2.0 del módulo al Jetson |
| Step-down **24 V → 19 V** | El módulo entrega 24 V y el Orin Nano se alimenta a 19 V. ⚠ A COMPLETAR: modelo |

## 2. Conexión

```
M300 (puerto OSDK) ══ OSDK Expansion Module
                        ├─ UART (TX, RX, GND · 3,3 V) ── FTDI ──USB──► Jetson  → /dev/ttyUSB0  921600 baudios
                        ├─ USB 2.0 ───────────────────────────────────► Jetson  → /dev/ttyACM0  ConfigTool, vídeo
                        └─ XT30 · 24 V ── step-down 24→19 V ───────► alimentación del Jetson (19 V)
```

1. Módulo en el puerto OSDK: **la cara del cable con la costura ("side B") hacia afuera** (DJI).
2. FTDI a los pines UART del módulo (el RX del módulo recibe lo que transmite el dron) y al USB del Jetson.
3. USB del módulo al Jetson. Acá el **módulo es el dispositivo USB y el Jetson el host** (DJI), al revés que en PSDK.
   ⚠ A COMPLETAR: a qué puerto del Orin va el cable en este modo.
4. Alimentación: XT30 del módulo (24 V, 4 A nominales) → step-down **24 V → 19 V** → Jetson. Nunca los 24 V
   directo al Orin. Si armás un cable propio, DJI pide usar
   los **4 pines VCC** a la vez. El pin ON_DET va usado, RSVD1 al aire y RSVD2 a GND (manual, p. 14).

## 3. Configuración del dron (una vez)

1. Crear una app **Onboard SDK** en <https://developer.dji.com/user/apps/>. De ahí salen `app_id` y `app_key`.
2. **DJI Assistant 2** (Enterprise): configurar el **baudrate del puerto OSDK** en 921600, el mismo de
   `cfg/UserConfig_osdk.txt`.

## 4. Host: el Jetson (una vez)

1. Docker con el runtime de NVIDIA y este repo en `~/multiUAV_system`.
2. Red: `host/netplan.yaml.example` → `/etc/netplan/50-cloud-init.yaml` (completar las contraseñas WiFi) y
   `sudo netplan apply`.
3. Hora desde el GCS: `sudo devices/common/boot/install.sh` (`GCS_HOST` en `/etc/muav/boot.env`).
4. **Nombres de host para el multimaster**: ROS 1 se conecta por NOMBRE. El del GCS va en el `/etc/hosts` del Jetson,
   y el del Jetson en el del GCS.
5. **Modo USB OSDK** (si antes se usó PSDK). La preparación de la primera vez está en `../psdk/SETUP.md` § 4:
   ```bash
   sudo devices/m300/host/set_usb_mode.sh osdk --now
   ```

## 5. Software (una vez, y tras cambiar un `.repos`)

```bash
cd ~/multiUAV_system/devices/m300/cfg
cp UserConfig_osdk.txt.example UserConfig_osdk.txt   # app_id, app_key, device /dev/ttyUSB0, baudrate, acm_port
git status                                           # NO debe aparecer: está gitignored
cd ~/multiUAV_system
devices/m300/container_build.sh                      # todo (horas: OpenCV CUDA y ROS 1 desde fuentes)
devices/m300/container_build.sh osdk                 # solo rehacer el workspace OSDK
```

`dji_vehicle_node.launch` no recibe argumentos: al arrancar, `devices/common/osdk/entrypoint_osdk.sh` reescribe sus
`<param>` con `UserConfig_osdk.txt`. El mismo archivo lo usa el ConfigTool (alias `M300-real` y `M300-sim-on`).

## 6. Arranque

```bash
MUAV_HOSTS=<gcs> tmuxinator start -p devices/m300/osdk/tmuxinator.yml ns=uav_14 mode=real   # -h: parámetros
```

> **Ojo: sin `mode=real` arranca en SIMULACIÓN** (`M300-sim-on`: vuelo simulado con el dron conectado por USB).

| Panel | Qué hace |
|---|---|
| `roscore` | Crea el contenedor y levanta el master (uno solo) |
| `config` | ConfigTool (`M300-real` o `M300-sim-on`, enciende la salida de potencia) y activa el stream de cámara |
| `mission` | `onboard_dji run_M300-rtsp.launch`: nodo DJI, misiones y vídeo (`simple_vs` + `ros_rtsp`) |
| `multimaster` | `multimaster_watch.sh`: espera al GCS y relanza el multimaster si no lo descubre |
| `shell` | Terminal dentro del contenedor |

A mano: `MUAV_HOSTS=<gcs> devices/m300/container_run.sh osdk [restart]`. Los streams RTSP salen de
`osdk/ros_rtsp_stream_setup.yaml`, montado encima del de `ros_rtsp`.

## 7. Verificación

- `container_run.sh` corta si falta `cfg/UserConfig_osdk.txt`, y avisa si no hay `ttyUSB0`/`ttyACM0` o si
  `MUAV_HOSTS` está vacío.
- En el GCS: `images/build.sh noetic` y `MUAV_HOSTS=<host del Jetson> ./container_run.sh bridge noetic`. Cada lado
  lista al OTRO. La interfaz `dji_M300` recibe telemetría (`dji_osdk_ros/*`).

## 8. Problemas comunes

| Síntoma | Causa probable |
|---|---|
| No aparece `/dev/ttyACM0` | El Jetson está en modo PSDK: `sudo devices/m300/host/set_usb_mode.sh osdk --now` |
| El multimaster no engancha | Nombres sin resolver en `/etc/hosts`, o varias interfaces de red: `export ROS_IP=<ip del Jetson en la red del GCS>` (y `ROS_HOSTNAME`) antes de arrancar |
| El dron "vuela" pero no se mueve | Arrancó en simulación: falta `mode=real` |
| `dji_vehicle_node` no activa | Credenciales de otra app, o baudrate distinto del de Assistant 2 |

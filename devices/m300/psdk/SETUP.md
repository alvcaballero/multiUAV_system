# M300 + PSDK (ROS 2 Humble): conexión y puesta en marcha

Guía para dejar un M300 RTK operando con `psdk_ros2` desde un Jetson Orin Nano. Se hace en este orden: hardware →
dron (DJI Assistant 2) → host (Jetson) → software → arranque → verificación.

Fuentes: [docs de `psdk_ros2`](https://github.com/arpoma16/psdk_ros2/tree/dev/integration/docs/documentation)
(GettingStarted: "Hardware connection", "Udev rules"), [DJI: device connection](https://developer.dji.com/onboard-sdk/documentation/quickstart/device-connection.html),
[DJI: puertos por aeronave](https://developer.dji.com/doc/payload-sdk-tutorial/en/quick-start/drone-port.html).
Lo marcado **⚠ A COMPLETAR** falta relevarlo en el dron.

## 1. Materiales

| Pieza | Nota |
|---|---|
| M300 RTK | Puerto **OSDK** (la PSDK del M300 también entra por ahí) |
| Jetson Orin Nano | L4T r36.4 (Ubuntu 22.04) |
| **OSDK Expansion Module** | Opción validada por `psdk_ros2` para el M300 (link `use_uart_and_usb_bulk_device`) |
| *o* **E-Port Development Kit** | DJI lo lista para el puerto OSDK del M300; `psdk_ros2` no lo validó en el M300. ⚠ A COMPLETAR: conexión y `link_config` con este kit |
| Adaptador USB-UART (FTDI) | **3,3 V**: el serial del M300 y del módulo es de 3,3 V (DJI) |
| Cable USB A-A | Del USB del módulo al Jetson |
| Step-down **24 V → 19 V** | El módulo entrega 24 V y el Orin Nano se alimenta a 19 V. ⚠ A COMPLETAR: modelo |

## 2. Conexión

```
M300 (puerto OSDK) ══ OSDK Expansion Module
                        ├─ UART (TX, RX, GND · 3,3 V) ── FTDI ──USB──► Jetson  → /dev/ttyUSB0   comandos y telemetría
                        ├─ USB 2.0 ──────────── cable USB A-A ───────► Jetson  → /dev/usb-ffs/bulk1, bulk2
                        │                                                        cámaras y archivos (USB bulk)
                        └─ XT30 · 24 V ── step-down 24→19 V ───────► alimentación del Jetson (19 V)
```

1. Montar el módulo en el puerto OSDK: **la cara del cable con la costura ("side B") hacia afuera** (DJI).
2. FTDI a los pines UART del módulo (el RX del módulo recibe lo que transmite el dron) y al USB del Jetson.
3. USB A-A del módulo al Jetson. En modo PSDK el Jetson actúa como **dispositivo USB** (gadget con dos endpoints
   bulk), así que el cable va al puerto del Orin que admite modo *device*.
   ⚠ A COMPLETAR: qué puerto físico del Orin Nano es.
4. Alimentación: XT30 del módulo (24 V, 4 A nominales) → step-down **24 V → 19 V** → Jetson. Nunca los 24 V
   directo al Orin.

> **Cuidado (docs de `psdk_ros2`)**: el OSDK Expansion Module saca **24 V**. Verificá que la computadora lo tolere o
> poné un step-down. Si armás un cable propio, DJI pide usar los **4 pines VCC** a la vez.

## 3. Configuración del dron (una vez)

1. Crear una app **Payload SDK** en <https://developer.dji.com/user/apps/>. De ahí salen `app_id`, `app_key`,
   `app_license` y la cuenta de desarrollador.
2. **DJI Assistant 2** (Enterprise) con el M300 conectado: configurar el **baudrate del puerto OSDK** (921600, el de
   `cfg/psdk_params.yaml`). Si no coinciden, prevalece el de Assistant 2 (docs de `psdk_ros2`).

## 4. Host: el Jetson (una vez)

1. Docker con el runtime de NVIDIA (`container_run.sh` usa `--runtime nvidia`) y este repo clonado en
   `~/multiUAV_system` (ahí lo buscan los tmuxinator; si no, `sys=<ruta>`).
2. Red: `sudo cp devices/m300/host/netplan.yaml.example /etc/netplan/50-cloud-init.yaml`, completar las contraseñas
   WiFi y `sudo netplan apply`. Deja `eth0` en `10.20.0.51/24` y `usb0` en `192.168.42.3/24`.
3. Hora desde el GCS al arrancar (el Jetson no tiene RTC con batería): `sudo devices/common/boot/install.sh` y poner
   `GCS_HOST` en `/etc/muav/boot.env` (ver `devices/common/README.md`).
4. **Modo USB PSDK.** La primera vez, preparar los dos scripts que alterna `host/set_usb_mode.sh`:
   ```bash
   # backup del script original de L4T (es el modo OSDK)
   sudo cp /opt/nvidia/l4t-usb-device-mode/nv-l4t-usb-device-mode-start.sh \
           /opt/nvidia/l4t-usb-device-mode/nv-l4t-usb-device-mode-start-osdk.sh
   # script de DJI para USB bulk: viene en usb-bulk-configuration-reference.zip (link en las docs de psdk_ros2)
   sudo cp startup_bulk/psdk-usb-configure.sh \
           /opt/nvidia/l4t-usb-device-mode/nv-l4t-usb-device-mode-start-psdk.sh
   ```
   Dejar el binario `startup_bulk` del mismo zip bajo `/home` (el script lo busca ahí; lo esperado es
   `~/Desktop/startup_bulk/startup_bulk`). Después, cada vez que se cambie de perfil:
   ```bash
   sudo devices/m300/host/set_usb_mode.sh psdk --now    # o sin --now: aplica en el próximo arranque
   sudo devices/m300/host/set_usb_mode.sh status        # modo, servicio L4T, startup_bulk, endpoints montados
   ```
5. Opcional: reglas udev para nombres fijos (`/dev/dji_serial`…). Plantilla en las docs de `psdk_ros2` (sección "Udev
   rules"). ⚠ A COMPLETAR: VID/PID del FTDI que se usa.

## 5. Software (una vez, y tras cambiar un `.repos`)

```bash
cd ~/multiUAV_system/devices/m300/cfg
cp psdk_params.yaml.example psdk_params.yaml    # app_id, app_key, app_license, developer_account; módulos y frecuencias
cp link_config.json.example link_config.json    # puertos UART y endpoints USB bulk (los del ejemplo son los del módulo)
git status                                      # NO deben aparecer: están gitignored
cd ~/multiUAV_system
devices/m300/container_build.sh                 # todo: opencv → ros2 → psdk → ros1 → osdk (horas)
devices/m300/container_build.sh psdk            # solo rehacer el workspace PSDK
```

- `psdk_wrapper` lee las credenciales de **sus parámetros ROS** (`psdk_params.yaml`), no de variables de entorno.
- Credenciales viejas en formato anterior: `cfg/legacy/`. Pasalas a mano a `psdk_params.yaml` y `link_config.json`.

## 6. Arranque

```bash
tmuxinator start -p devices/m300/psdk/tmuxinator.yml ns=uav_16      # -h: parámetros
```

| Panel | Qué hace |
|---|---|
| `psdk` | Crea el contenedor y lanza `psdk_wrapper` con `cfg/psdk_params.yaml` y `cfg/link_config.json` |
| `streaming` | A los 30 s activa el streaming de la cámara principal (`camera_setup_streaming`) |
| `camera` | `rtsp_bridge`: cámara → RTSP hacia el mediamtx del GCS |
| `notify` | `mission_notifier`: avisa al GCS el fin de misión (`/GCS/GCSCommand`) |
| `download` | `downloader`: sirve la descarga de archivos por fecha |
| `shell` | Terminal dentro del contenedor |

A mano: `devices/m300/container_run.sh psdk [restart] [--no-bulk]` (`--no-bulk`: solo UART, sin cámaras).

## 7. Verificación

- `container_run.sh` ya corta si falta `cfg/psdk_params.yaml` o `cfg/link_config.json`, o si no existen
  `/dev/usb-ffs/bulk1,2`. También avisa si no ve `ttyUSB0`/`ttyACM0` o si `startup_bulk` no corre.
- Dentro del contenedor: `ros2 topic list | grep uav_16` muestra la telemetría de `psdk_ros2`.
- En el GCS: `images/build.sh humble` y `./container_run.sh bridge humble`, con el **mismo `ROS_DOMAIN_ID`** y en la
  misma red. La interfaz `dji_M300_PSDK` recibe telemetría (`psdk_interfaces/msg/*`).

## 8. Problemas comunes

| Síntoma | Causa probable |
|---|---|
| `/dev/usb-ffs/bulkN no existe` | El Jetson está en modo OSDK: `sudo devices/m300/host/set_usb_mode.sh psdk --now` |
| Telemetría sí, cámara no | `startup_bulk` no corre, o se arrancó con `--no-bulk` |
| El wrapper no inicializa | Credenciales de otra app, o baudrate distinto del de Assistant 2 |
| No aparece `/dev/ttyUSB0` | FTDI desconectado o sin alimentación |
| El GCS no ve nada | Otro `ROS_DOMAIN_ID`, otra red, o el GCS usa `bridge:noetic` en vez de `bridge:humble` |

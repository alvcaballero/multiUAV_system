# PX4 por ROS 2 (uXRCE-DDS, Jazzy): conexión y puesta en marcha

Guía para dejar un dron PX4 hablando ROS 2 con el GCS: el cliente uXRCE-DDS del firmware se conecta al **Agent** de la
companion y los topics aparecen en `/uav_<id>/fmu/...`. Orden: hardware → firmware (parámetros) → host → software →
arranque → verificación. El porqué de las versiones está en `README.md` de esta carpeta.

Fuentes: parámetros leídos en `src/modules/uxrce_dds_client/module.yaml` de PX4 (línea del contrato,
`devices/px4_ros2/px4.env`); [PX4: uXRCE-DDS](https://docs.px4.io/main/en/middleware/uxrce_dds.html).
Lo marcado **⚠ A COMPLETAR** falta relevarlo en el dron.

## 1. Materiales

| Pieza | Nota |
|---|---|
| Autopiloto con PX4 | ⚠ A COMPLETAR: modelo. Firmware = el del contrato (`px4.env`, `f629d451`); otro → translation node (§ 6) |
| Companion | x86 o arm64 con Docker (el contenedor es Ubuntu 24.04 aunque el host no lo sea; no necesita GPU). ⚠ A COMPLETAR: modelo |
| Enlace | **Serie**: adaptador USB-UART a un puerto TELEM, o **Ethernet** si el autopiloto lo tiene |
| Alimentación de la companion | ⚠ A COMPLETAR: desde qué salida del dron y con qué regulador |

## 2. Conexión

```
Serie:     Autopiloto TELEM2 (TX, RX, GND) ── USB-UART ──USB──► companion  → /dev/ttyUSB0  921600 baudios
Ethernet:  Autopiloto ETH ───────────────── cable ─────────► companion  → Agent en UDP 8888
```

TX del autopiloto al RX del adaptador y viceversa, GND común. ⚠ A COMPLETAR: qué TELEM se usa en este dron y el
nivel lógico del adaptador.

## 3. Firmware: parámetros (QGroundControl, una vez; requieren reinicio)

| Parámetro | Valor | Para qué |
|---|---|---|
| `UXRCE_DDS_CFG` | el puerto elegido (`TELEM2`, o `Ethernet`) | Dónde corre el cliente uXRCE-DDS |
| `SER_TEL2_BAUD` | 921600 (solo serie, si es TELEM2) | El mismo baudrate que el Agent |
| `UXRCE_DDS_NS_IDX` | `<id>` | Namespace `uav_<id>`: el que esperan el offboard y el GCS |
| `UXRCE_DDS_DOM_ID` | el `ROS_DOMAIN_ID` del sistema (por defecto 0) | Si no coincide, el GCS no ve nada |
| `MAV_SYS_ID` | `<sysid>` (por defecto = `<id>`) | El offboard lo usa para mandar comandos |
| `UXRCE_DDS_AG_IP` | IP de la companion **como entero** (192.168.1.2 = `-1062731518`) | Solo Ethernet: PX4 no acepta la IP como texto |
| `UXRCE_DDS_PRT` | 8888 | Solo Ethernet |

## 4. Host: la companion (una vez)

1. Docker y este repo en `~/multiUAV_system`.
2. Red con el GCS, con el mismo `ROS_DOMAIN_ID` (el descubrimiento es DDS: no hay multimaster ni `/etc/hosts`).
   ⚠ A COMPLETAR: IP fija y netplan de este dron.
3. Si no tiene RTC con batería, hora desde el GCS: `sudo devices/common/boot/install.sh`.

## 5. Software

```bash
images/build.sh jazzy base                # en la companion (multi-arch)
devices/px4_ros2/container_build.sh       # Agent + offboard + mqtt_client + translation node
```

PX4 no usa credenciales: no hay `cfg/`.

## 6. Arranque

```bash
tmuxinator start -p devices/px4_ros2/tmuxinator.yml id=1                          # serie, GCS por rosbridge
tmuxinator start -p devices/px4_ros2/tmuxinator.yml id=1 agent="udp4 -p 8888"     # Ethernet
tmuxinator start -p devices/px4_ros2/tmuxinator.yml id=1 broker=<ip GCS>          # + protocolo mqtt
tmuxinator start -p devices/px4_ros2/tmuxinator.yml id=1 translate=true           # firmware ≠ px4.env
tmuxinator start -p devices/px4_ros2/tmuxinator.yml -h                            # parámetros
```

Paneles: `agent` (MicroXRCEAgent), `translation` (si `translate=true`), `offboard` (`offboard_mission_bt`),
`heartbeat` (`gcs_heartbeat`) y `mqtt` (si hay `broker`). A mano: `devices/px4_ros2/container_run.sh [restart]`.

## 7. Verificación

- El Agent muestra la sesión del cliente al conectarse (`session established` o similar en el panel `agent`).
- Dentro del contenedor: `ros2 topic list | grep uav_<id>/fmu` lista `vehicle_status_v4`, `battery_status_v1`…
- En el GCS: `./container_run.sh bridge jazzy` (no humble: el contrato de PX4 es el de Jazzy) con el mismo
  `ROS_DOMAIN_ID`. La interfaz `px4_ros2` recibe telemetría de `uav_<id>`.

## 8. Problemas comunes

| Síntoma | Causa probable |
|---|---|
| El Agent no ve al cliente | Baudrate distinto, TX/RX cruzados mal, o `UXRCE_DDS_CFG` en otro puerto |
| Topics sin `uav_<id>` | `UXRCE_DDS_NS_IDX` sin configurar o sin reiniciar el autopiloto |
| Topics sí, el GCS no | `UXRCE_DDS_DOM_ID` / `ROS_DOMAIN_ID` distintos, o se usó `bridge:humble` |
| Topics `_v1` donde el GCS espera `_v4` | Firmware de otra versión: `translate=true` |

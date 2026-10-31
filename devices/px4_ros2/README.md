# px4_ros2: dron PX4 por ROS 2 (Jazzy)

PX4 habla uORB ↔ DDS con su cliente uXRCE-DDS; en la companion corren el **Agent**, el offboard del proyecto
(`MUAV_px4_offboard`) y, si hace falta, el **translation node**. El GCS lo ve por `bridge:jazzy` (rosbridge, interfaz
`px4_ros2`) o por MQTT (`mqtt_client`).

| Archivo | Qué es |
|---|---|
| `Dockerfile` | Sobre `muav/base:jazzy` (multi-arch). Contrato + `jazzy.repos` + translation node, compila solo lo que piden |
| `jazzy.repos` | `MUAV_px4_offboard`, `mqtt_client` (por commit) |
| `agent.repos` | Agent XRCE-DDS `v2.4.3`: lo comparten el dron y `dev` (todas las distros ROS 2) |
| `px4.env` | El PX4 del contrato (`f629d451`): de ahí sale el translation node y el SITL de `dev:jazzy` |
| `fetch_translation_node.sh` | Trae `translation_node` y `px4_msgs_old` de ese PX4 (un commit, dos carpetas) |
| `container_build.sh` / `container_run.sh` | Build y arranque EN la companion |
| `tmuxinator.yml` | Agent + offboard + heartbeat (+ translation node, + bridge MQTT) |

## Versiones (por qué estas)

- **`px4_msgs` `6cdc4f5`** (contrato, decisión 19): coincide con lo que escucha el GCS (`vehicle_status_v4`,
  `battery_status_v1`, `vehicle_local_position_v1`, `vehicle_command_ack_v1`). `main` ya pasó a `VehicleStatus` v5.
- `MUAV_px4_offboard` arma los topics `fmu/out` con el `MESSAGE_VERSION` del `px4_msgs` con que se compila, y le
  manda al GCS ESA estructura. Por eso **no hay perfil Humble**: compilado contra `px4_msgs` `v1.15.4` (contrato
  Humble), el GCS recibiría otra forma de mensaje. El contenedor Jazzy (Ubuntu 24.04) corre en un host 22.04 sin
  problema: no necesita CUDA, a diferencia del M300.
- **Agent `v2.4.3`** (decisión 20): su `colcon.pkg` compila contra el Fast-DDS de ROS (sin superbuild), igual que el
  que corre en `~/ros2_px4_ws`.

## Firmware

- Namespace: `UXRCE_DDS_NS_IDX=<id>` → el cliente publica en `/uav_<id>/fmu/...` (requiere reboot). `id` del
  tmuxinator = ese número.
- Enlace serie: el puerto TELEM con `UXRCE_DDS_CFG` y su baudrate (por defecto del tmuxinator: `/dev/ttyUSB0`,
  921600). Por Ethernet: `agent="udp4 -p 8888"`.
- **Firmware distinto de `px4.env`** (por ejemplo 1.15): `translate=true`. El translation node solo traduce versiones que
  conoce, así que se compila del PX4 más nuevo de los dos lados (el del contrato). Un firmware MÁS NUEVO que el
  contrato no se traduce: hay que subir el contrato (`jazzy.repos` + `px4.env`, juntos).

## Uso

```bash
images/build.sh jazzy base                 # en la companion (multi-arch)
devices/px4_ros2/container_build.sh
tmuxinator start -p devices/px4_ros2/tmuxinator.yml id=1                  # GCS por rosbridge
tmuxinator start -p devices/px4_ros2/tmuxinator.yml id=1 broker=<ip GCS>  # + protocolo mqtt
tmuxinator start -p devices/px4_ros2/tmuxinator.yml -h                    # parámetros
```

Desarrollar a bordo: `PX4_ROS2_DEV_SRC=<dir> devices/px4_ros2/container_run.sh restart` monta `<dir>` en
`/root/app_ws/src/external`.

Sin hardware: `dev:jazzy` trae el mismo PX4 en SITL + Gazebo Harmonic y el mismo Agent:
`images/dev/tmuxinator_px4_ros2_sim.yml`.

## Fuera

- Vídeo (`video_stream_compress.launch.py` del offboard): no estaba en lo que corre a bordo (`locscene_obstacles.yaml`).
- `mavlink-router` (estaba en `px4_ros2_docker`): el GCS no lo pide para `px4_ros2`.

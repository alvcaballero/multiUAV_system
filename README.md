# multiUAV_system

Sistema GRVC para operar un equipo heterogéneo de UAVs (proyectos AERIAL-CORE, OMICRON, RESISTO, entre otros).

Este repo **es el sistema**: los entornos (Docker) del GCS, de desarrollo y de cada dron, y el **contrato de
mensajes** que comparten. No tiene paquetes ROS propios: el código entra por `.repos`, fijado por commit.
El plan y las decisiones de diseño están en [`docs/plans/environments.md`](docs/plans/environments.md).

## Mapa

```
images/                       lo COMPARTIDO, un Dockerfile por rol con ARG ROS_DISTRO
  base/                       ROS + vcstool + colcon (+ catkin-tools en noetic)
  msgs/<distro>.repos         EL CONTRATO: todos los mensajes del sistema, fijados por commit
  bridge/                     rosbridge del GCS (+ multimaster en noetic, hosts por MUAV_HOSTS)
  dev/                        desarrollo: bridge dentro, PX4 SITL con código (Gazebo 11 en noetic, Harmonic + Agent
                              XRCE en humble y jazzy), drones falsos ROS 1 (mock/). humble = px4_ros2_docker
  build.sh <distro>           construye base → msgs → bridge → dev
devices/                      un dispositivo por carpeta, con TODO lo suyo (Dockerfile, .repos, tmuxinator, README)
  m300/                       DJI M300 (Jetson Orin Nano): PSDK/Humble y OSDK/Noetic
  m210/                       DJI M210 (Raspberry Pi): OSDK/Noetic
  vtol/                       PX4 por mavros (Raspberry Pi): Noetic
  px4_ros2/                   PX4 por uXRCE-DDS (companion x86/arm64): Jazzy, translation node opcional
  common/                     compartido entre drones: Onboard-SDK, multimaster con watchdog, hora desde el GCS
.devcontainer/                VS Code: plantilla; <distro>/ lo genera images/build.sh (GPU detectada, gitignored)
container_run.sh              dev | bridge <distro>, o un dispositivo
ws/<distro>/                  workspace de desarrollo por defecto (gitignored), montado en /ws del contenedor dev
multiuav_gui/                 GCS, submódulo: última versión verificada con este sistema
```

```
base:<distro> ─► msgs:<distro> ─┬─► bridge:<distro>   (GCS)
                                └─► dev:<distro>      (desarrollo)
devices/<x>: su propia base (Jetson L4T, o base:<distro>) + vcs import del contrato + sus .repos
```

| Distro | Contrato | Bridge | Dispositivos |
|---|---|---|---|
| Noetic | `muav_gcs_interfaces` rama `ros1` (`aerialcore_common` + `multiuav_interfaces`), `dji_osdk_ros` | rosbridge + multimaster | M300 OSDK, M210, VTOL |
| Humble | `muav_gcs_interfaces`, `psdk_interfaces`, `px4_msgs` v1.15.4 | rosbridge | M300 PSDK |
| Jazzy | `muav_gcs_interfaces`, `px4_msgs` `6cdc4f5` (= PX4 `f629d451`, topics `_v4`/`_v1`) | rosbridge | PX4 ROS 2 |

## Uso rápido

```bash
# GCS: bridge de una distro
images/build.sh noetic
MUAV_HOSTS=<drones> ./container_run.sh bridge noetic       # ROS 1: multimaster con los drones
./container_run.sh bridge humble                           # ROS 2: descubrimiento por DDS

# Desarrollo: monta ws/<distro> en /ws (ver "Desarrollo" abajo)
vcs import ws/noetic/src < devices/vtol/noetic.repos       # el código que quieras tocar
./container_run.sh dev noetic
vcs import ws/humble/src < images/dev/humble.repos         # PSDK (psdk_ros2 es solo Humble)
./container_run.sh dev humble

# Ver el GCS sin hardware (dentro de dev:noetic)
roscore & /opt/muav/bridge/start.sh & /opt/muav/mock/mock_fleet.sh

# PX4 ROS 2 simulado (SITL + Gazebo Harmonic + Agent + offboard + rosbridge)
vcs import ws/jazzy/src < devices/px4_ros2/jazzy.repos     # y colcon build dentro de dev:jazzy
tmuxinator start -p images/dev/tmuxinator_px4_ros2_sim.yml

# En un dron: ver devices/<x>/README.md
```

Un mensaje nuevo se declara **una sola vez**, en `images/msgs/<distro>.repos`. Las credenciales (DJI, VPN, WiFi)
nunca van a git: cada dispositivo tiene `cfg/*.example`.

## Desarrollo

```
imagen muav/dev:<distro>   se reconstruye; nada tuyo vive acá
  /opt/ros/<distro> → /opt/muav/msgs (contrato) → /opt/muav/tools (Agent, jazzy) → /ws   (overlays, muav_env.sh)
  /opt/px4/PX4-Autopilot   PX4 con código, compilado (noetic v1.14.4, humble v1.15.4, jazzy el del contrato)
  /opt/muav/dev_env.sh     PX4_DIR, GZ_* (humble: PX4-gazebo-models)
volumen  ws/<distro> (o $MUAV_WS_<DISTRO>)  →  /ws     src, build, install y log quedan en el HOST
```

| Distro | Para qué | Gazebo | PX4 SITL | Código de partida |
|---|---|---|---|---|
| noetic | drones ROS 1 (OSDK, mavros) | 11 (classic) | v1.14.4 | `devices/<x>/noetic.repos` |
| humble | PSDK (M300) y PX4 1.15. = `~/work/px4_ros2_docker` | Harmonic + `ros_gzharmonic` | v1.15.4 | `images/dev/humble.repos` |
| jazzy | PX4 ROS 2 (`devices/px4_ros2`) | Harmonic + `ros_gz` | `f629d451` (contrato) | `devices/px4_ros2/jazzy.repos` |

- **Workspaces del contenedor, no del host.** Cada distro tiene el suyo (`ws/<distro>`, gitignored) con clones
  PROPIOS: se sincronizan con tu entorno local por git (push/pull), no compartiendo disco. NUNCA montes un workspace
  compilado en el host (como `~/ros2_px4_ws`, Jazzy nativo): sus rutas absolutas no existen en `/ws` y un `colcon
  build` dentro le pisa `build/` e `install/`. `container_run.sh` y el devcontainer lo detectan y cortan.
- **Todo el workspace vive en el host**: recrear el contenedor o reconstruir la imagen no borra código ni compilación.
  Las dependencias de apt sí viven en el contenedor: `/opt/muav/ws_rosdep.sh` (el devcontainer lo corre al crearse).
- **Otro directorio**: `MUAV_WS_<DISTRO>=<dir>` (una variable por distro), para un segundo workspace del contenedor.
- **Terminal / tmux**: `./container_run.sh dev humble` crea `muav_dev_humble` o entra con `docker exec`; `restart` lo
  recrea. Si el contenedor existente monta OTRO workspace, corta con error en vez de compilar donde no creés.
- **VS Code**: `images/build.sh <distro>` construye y genera `.devcontainer/<distro>/devcontainer.json` (como
  `createContainer.sh`: detecta la GPU NVIDIA). Abrir este repo → *Reopen in Container* → `muav dev:<distro>`. zsh +
  oh-my-zsh, ROS cargado en bash y zsh. Si cambia la GPU: `.devcontainer/generate.sh <distro>`.
- **Los dos a la vez**: con el devcontainer en marcha (`muav_devcontainer_<distro>`), `container_run.sh dev <distro>`
  y los tmuxinator entran en ÉL: un solo entorno. Cerrar VS Code no lo para (`shutdownAction: none`):
  `docker stop muav_devcontainer_<distro>`.
- `ROS_DOMAIN_ID` del host pasa a dev, bridge y drones.
- Los archivos que se crean en `/ws` son de root (el contenedor corre como root).

## Repos relacionados

| Repo | Qué |
|---|---|
| [multiuav_gui](https://github.com/alvcaballero/multiuav_gui) | GCS (submódulo) |
| [onboard_dji](https://github.com/alvcaballero/onboard_dji) | Nodos a bordo DJI por OSDK (ramas `M300`, `M210`) |
| [onboard_px4](https://github.com/alvcaballero/onboard_px4) | Nodos a bordo PX4 por mavros |
| [MUAV_GCS_interfaces](https://github.com/arpoma16/MUAV_GCS_interfaces) | Mensajes del GCS (`main`: ROS 2, `ros1`: ROS 1) |
| [MUAV_psdk_offboard](https://github.com/arpoma16/MUAV_psdk_offboard) | Nodos a bordo DJI por PSDK |
| [MUAV_px4_offboard](https://github.com/arpoma16/MUAV_px4_offboard) | Nodos a bordo PX4 por ROS 2 (offboard, heartbeat, bridge MQTT) |

# Plan: entornos ROS del sistema (GCS, dispositivos, desarrollo)

Estado: **en curso**. Alcance: SOLO este repo. Los demás repos (onboard_dji, onboard_px4, px4_ros2_docker, el GCS,
la carpeta `~/work/M300`) no se modifican: de ellos se copia lo útil y se referencian por `.repos`.

## Problema

Cada contenedor arrancaba de cero y vivía en un sitio distinto, así que nada se podía referenciar:

| Pieza | Dónde estaba | Problema |
|---|---|---|
| Entorno ROS 1 de desarrollo | `docker/` + `~/work/ros_docker_volume` | Volumen sin versionar, ruta hardcodeada, clona por RAMA (`GimbalPitch`) |
| Entorno M300 | `multiuav_bringup/devices/M300/docker` + `~/work/M300` (no es repo git) | Copias con remote `ssh://...10.20.0.2`, no GitHub |
| Entorno PX4 ROS 2 | `px4_ros2_docker` (otro repo) | README dice Humble/PX4 1.15; el GCS espera Jazzy/`px4_msgs` main |
| Bridge del GCS | Imagen `muavgcs:ros1` construida a mano | Nadie sabe de qué Dockerfile sale; `Dockerfile.gcs` hereda una imagen de desarrollo completa |
| Mensajes | Repetidos en cada workspace | Un mensaje nuevo hay que añadirlo en cada lado |

## Decisiones

1. **Este repo es el sistema**: entornos, dispositivos y el contrato de mensajes. No contiene paquetes ROS propios:
   el código entra por `.repos`.
2. **Una carpeta por dispositivo con TODO lo suyo** (Dockerfile, `.repos`, tmuxinator, qué instalar a bordo).
   Lo compartido va en `images/`.
3. **Carpetas por distro, NO ramas por distro.** El GCS necesita bridges de varias distros a la vez, lo común
   (`devices/common`, scripts) no se triplica y hay dispositivos en dos distros (PX4 Humble y Jazzy).
4. **Un bridge por distro** (`noetic`, `humble`, `jazzy`). Probado: la comunicación Humble↔Jazzy no va bien.
5. **El contrato = `images/msgs/<distro>.repos`.** Todos los paquetes de mensajes del sistema. Bridge, dev y
   dispositivos los heredan; un mensaje nuevo se declara UNA vez.
6. **El contrato es el ARCHIVO `.repos`, no la imagen.** Las imágenes x86 (bridge, dev) heredan de `msgs:<distro>`.
   Un dispositivo con hardware propio (M300: Jetson Orin Nano, L4T r36.4, arm64, OpenCV CUDA) tiene su
   contenedor ESPECÍFICO con su propia base, y dentro hace `vcs import < images/msgs/<distro>.repos`: mismos
   mensajes y misma versión, sin heredar una imagen x86. No se fuerza una cadena de `FROM` común a todo.
7. **Mensajes OSDK: el mismo `Onboard-SDK-ROS`, compilado solo-interfaces en el bridge** (revisada 2026-10-31; antes
   decía "repo propio de solo-mensajes", ver Pendientes). El paquete se sigue llamando **`dji_osdk_ros`**: rosbridge
   identifica el tipo por `paquete/Mensaje` y ROS 1 compara el MD5 de la definición. Con otro nombre, deja de
   interpretarse sin error.
8. **`multiuav_interfaces` sale a su repo** y entra por `images/msgs/noetic.repos`.
9. **`multiuav_bringup` se vacía hacia `devices/` y se borra.** Su contenido sí se usa; lo que sobra es que sea
   un paquete catkin.
10. **`connect_uas.launch` deja de ser un launch por proyecto**: es configuración del bridge ROS 1 (multimaster +
    rosbridge). Va en `images/bridge/` con los hosts como variable (`MUAV_HOSTS`), no hardcodeados. Las dos
    copias que existen solo difieren en la lista de hosts.
11. **El GCS sigue como submódulo, con significado de "última versión verificada"** con este sistema. El
    desarrollo diario del GCS se hace en su propio checkout; el puntero aquí se actualiza a propósito tras
    probar el conjunto. El GCS ha mantenido compatibilidad con todos los dispositivos actuales.
12. **Las versiones se fijan con tag o commit en los `.repos`, no con rama.** "Congelar" ROS 1 es eso.
13. **Desarrollo: un contenedor por distro con el bridge dentro.** Los mensajes salen del mismo `msgs`, así que
    la diferencia con producción es solo el `FROM` final.
14. **`psdk_interfaces` sale del fork `arpoma16/psdk_ros2` (`dev/integration`)**, también en el M300. Hoy el M300
    NO lo usa: `Dockerfile.psdk` instala `ros-humble-psdk-interfaces`/`psdk-wrapper` por apt y
    `~/work/M300/app_ros2/psdk_ros2` es el upstream `umdlife` en `feat/waypoint-v2`. R1 lo pasa al fork.
15. **PX4: contrato en `px4_msgs` `v1.15.4`** (rama `release/1.15`, la que ya usa `px4_ros2_docker`). Otra versión
    de PX4 = otro contenedor de dispositivo con su versión, no otro contrato. La compatibilidad entre versiones de
    mensajes la da el **message translation node** de PX4 (`PX4-Autopilot/msg/translation_node`, ver
    `multiuav_gcs/infra/external.md` › Versiones de mensajes de PX4). Resuelto: no es un pendiente de este plan.

## Estructura objetivo

```
multiUAV_system/
  images/                     lo COMPARTIDO
    base/                     Dockerfile por distro (ARG BASE_IMAGE): noetic | humble | jazzy
    msgs/                     Dockerfile + noetic.repos humble.repos jazzy.repos   ← el contrato
    bridge/                   rosbridge (+ multimaster en noetic, hosts por MUAV_HOSTS)   → GCS
    dev/                      compiladores, sim, bridge dentro
  devices/
    common/                   init a bordo: rc.local, synchdate, multimaster, VPN
    m300/  m210/  m600/  px4_ros2/  px4_mavros/  vtol/
      Dockerfile  <x>.repos  tmuxinator.yml  README.md (qué instalar a bordo y cómo)
  container_run.sh            container_run.sh <imagen|dispositivo>
  ws/                         gitignored: noetic/src  humble/src  jazzy/src
  multiuav_gui/               submódulo (decisión 11)
```

Encadenado (producción):

```
base:<distro> ─► msgs:<distro> ─┬─► bridge:<distro>   (GCS)
                                ├─► dev:<distro>      (desarrollo)
                                └─► devices/<x>       (+ SDK y paquetes propios del dispositivo)
```

Desarrollo: `vcs import ws/<distro>/src < images/msgs/<distro>.repos` (+ el `.repos` del dispositivo). El
contenedor dev monta `ws/<distro>`; se edita en el host y se compila dentro. `ws/` reemplaza a
`~/work/ros_docker_volume`.

## De dónde sale cada cosa

| Hoy | Destino |
|---|---|
| `docker/Dockerfile.gcs` | `images/base/noetic` + `images/dev/noetic` (separar deps comunes de las de desarrollo) |
| `docker/Dockerfile.sim`, `initDev.sim.sh` | `images/dev/noetic` (perfil sim: PX4 v1.14.4 + Gazebo 11) |
| `docker/initDev*.sh` | `devices/*/*.repos` + `images/msgs/noetic.repos` (`vcs import`, versión fijada) |
| `docker/Dockerfile`, `Production.Dockerfile`, `createContainer.sh` | Se borran (legado; `Production.Dockerfile` hereda `muavgcs:noetic`, imagen sin origen) |
| `docker/container_run.sh` | `container_run.sh` (raíz), sin ruta hardcodeada: monta `ws/<distro>` |
| `multiuav_bringup/devices/M300/docker/*` | `devices/m300/` (osdk y psdk como perfiles) |
| `multiuav_bringup/devices/{M210,M600,vtol}` | `devices/<x>/` |
| `multiuav_bringup/devices/init/` | `devices/common/` |
| `multiuav_bringup/launch/connect_uas.launch` | `images/bridge/` (decisión 10) |
| `multiuav_bringup/launch/simulate_*.launch`, `scripts/` | `images/dev/` si se usan; si no, se borran |
| `multiuav_interfaces/` | Repo propio → `images/msgs/noetic.repos` |
| Submódulos `onboard_dji`, `onboard_px4` | Entradas en `devices/m210/m210.repos`, `devices/px4_mavros/px4_mavros.repos` |
| `~/work/M300/app_ros1`, `app_ros2` | Revisar y copiar lo útil a `devices/m300/` (tmuxinator `M300-PSDK-ROS2.yml`, `camera_*`) |
| `px4_ros2_docker` | Base de `devices/px4_ros2/` + `images/dev/{humble,jazzy}` (copiar, no tocar el repo original) |

Credenciales DJI (`dji_psdk_config.json`, `UserConfig_*.txt`): siguen fuera de git; solo `.example` versionado.

## Migración por rebanadas

Cada rebanada es una rama de trabajo que se mergea y termina funcionando de punta a punta. Lo viejo sigue vivo
hasta que su rebanada termina.

### R1 — Humble + M300 (PSDK)
1. `images/base/humble` (x86, `ros:humble`).
2. `images/msgs/humble.repos` + Dockerfile.
3. `images/bridge/humble` y `images/dev/humble`.
4. `devices/m300/`: contenedor específico Jetson (cadena opencv → ros2 → psdk de
   `multiuav_bringup/devices/M300/docker`) + `vcs import` de `images/msgs/humble.repos` + lo útil de
   `~/work/M300/app_ros2`. `psdk_interfaces`/`psdk_wrapper` desde el fork, no por apt (decisión 14).
5. Verificar: el GCS recibe telemetría PSDK por `bridge:humble`.

Estado (2026-10-31): pasos 1-4 escritos, **sin construir ni probar**. Falta el 5. Implementación:
- Un Dockerfile por ROL con `ARG ROS_DISTRO` (`images/{base,msgs,bridge,dev}/Dockerfile`), tags `muav/<rol>:<distro>`,
  build context = raíz del repo. `images/build.sh <distro> [roles]` construye la cadena.
- `msgs` compila solo los paquetes `*_msgs|*_interfaces` del `.repos` en `/opt/muav/msgs` (psdk_ros2 trae también
  `psdk_wrapper`, que compila el dispositivo).
- `container_run.sh dev|bridge <distro>` en la raíz; `container_run.sh <dispositivo>` delega en `devices/<x>/`.
- **Un `.repos` por distro también en los dispositivos** (`devices/<x>/<distro>.repos`). El M300 tiene `humble.repos`
  (PSDK) y tendrá `noetic.repos` (OSDK, R2). Sin Jazzy: `psdk_ros2` solo está probado en Humble y L4T r36.4 es
  Ubuntu 22.04 (Jazzy solo tiene apt para 24.04).
- `devices/m300`: el workspace de la imagen toma las versiones de `images/msgs/humble.repos` + `devices/m300/humble.repos`,
  pero compila solo `--packages-up-to psdk_wrapper muav_psdk_offboard`. **Precisión a la decisión 6**: el contrato
  es lo que el BRIDGE deserializa (la unión); un dispositivo compila solo los mensajes que sus paquetes declaran en
  `package.xml`, en la versión del contrato. El M300 no compila `px4_msgs`.
- Hallazgos que cambiaron lo que se copió del M300:
  - `psdk_wrapper` lee las credenciales de sus PARÁMETROS ROS (`psdk_params.yaml`), no de env: `UserConfig_psdk.txt`
    y el export de `PSDK_APP_*` del entrypoint viejo no hacían nada. Ahora: `cfg/psdk_params.yaml` +
    `cfg/link_config.json` (gitignored, `.example` versionado) montados en `/root/cfg`.
  - Fuera `ros-humble-as2-platform-dji-psdk` (apt): arrastra `psdk-wrapper`/`psdk-interfaces` de apt, que es justo
    lo que la decisión 14 elimina. El tmuxinator no lanzaba aerostack2.
  - Fuera el clon de Payload-SDK 3.9.2 en `/opt/payload-sdk` (era para el wrapper de apt): el wrapper del fork lo
    baja con FetchContent (3.8.1, fijado en su `CMakeLists.txt`).
  - `camera_file_downloader`/`camera_rtsp_bridge` de `app_ros2` NO se copian: superados por `MUAV_psdk_offboard`.
  - Commits fijados al tip del REMOTE (`psdk_ros2` `8b65dd5`, `MUAV_psdk_offboard` `bb5c074`): los checkouts
    locales de `px4_ros2_docker` estaban 3 y 4 commits atrás.

### R2 — Noetic + M210 / M300 OSDK / PX4 mavros
1. Requiere el repo de mensajes `dji_osdk_ros` y el de `multiuav_interfaces`.
2. `images/{base,msgs,bridge,dev}/noetic`; `bridge` absorbe `connect_uas.launch`.
3. `devices/{m210,px4_mavros,m600,vtol}` y el perfil osdk de `devices/m300`.
4. Fijar commits en los `.repos` (adiós `GimbalPitch` como rama).
5. Borrar `docker/`, `multiuav_bringup/`, `multiuav_interfaces/` y los submódulos `onboard_*`.

### R3 — Jazzy + PX4 ROS 2
1. `images/{base,msgs,bridge,dev}/jazzy`; `devices/px4_ros2` con `ARG ROS_DISTRO` (humble | jazzy).
2. Copiar desde `px4_ros2_docker` lo necesario.

### Después (fuera de este repo, cuando se decida)
- GCS: `infra/compose/compose.ros*.yaml` apunta a `bridge:<distro>`; `infra/repos/` y la parte de mensajes de
  `infra/external.md` pasan a citar este repo; `infra/local.env` con una sola `MUAV_SYSTEM_DIR`.
- Actualizar el puntero del submódulo `multiuav_gui` (hoy `7d4b1df`, `v1.4-184`).

## Pendientes

- **Noetic en Jetson**: L4T r36.4 es Ubuntu 22.04 y Noetic no tiene apt para Jammy. **Corregido (2026-10-31)**: la
  imagen que se usa (`ros-noetic:l4t-r36.4.0`) NO sale de `jetson-containers` (eso es solo una nota en
  `~/work/M300/app_ros1/Readme.md`) sino de `Dockerfile.ros1`, que compila ROS desde fuentes (~40 clones, varios por
  RAMA `*-devel`/`master`: fijar en R2). Es el perfil osdk de `devices/m300`, no `images/base/noetic`.
- **M300 OSDK relevado (2026-10-31)**: `devices/m300/noetic.repos` escrito (sin Dockerfile todavía). El workspace a
  bordo = imagen (`Onboard-SDK-ROS`, `multimaster_fkie`) + `~/work/M300/app_ros1` montado (`multiUAV_system` main,
  `ros_rtsp`, `simple_vs`). Sin trabajo perdido: `run_M300-rtsp.launch` sin trackear ya está en `onboard_dji`
  `origin/M300` (`5e0e501`); lo de `simple_vs` es solo modo de archivos + un default; la config de `ros_rtsp` se copió
  a `devices/m300/config/`. `app_ros1/docker` es una versión ANTERIOR de `multiuav_bringup/devices/M300/docker`
  (solo cambia el nombre del entrypoint y OpenCV `4.x` sin fijar); `try2/` y `docker2/` son restos.
- **`aerialcore_common` vs `multiuav_interfaces` (afecta a la decisión 8)**: toda la flota ROS 1 corre
  `aerialcore_common` y las interfaces del GCS (`dji_M300.yaml`, `dji_M210_noetic.yaml`, `px4_mavros.yaml`,
  `griffin.yaml`) piden `aerialcore_common/ConfigMission`. El código del GCS ya acepta los dos nombres
  (`msgEncode.js:76`), pero rosbridge carga la clase POR NOMBRE de paquete. Con solo `multiuav_interfaces` en
  `bridge:noetic`, los drones actuales dejan de funcionar. Decidir antes de escribir `images/msgs/noetic.repos`.
- **Decisión 7 revisada (2026-10-31): sin repo aparte de solo-mensajes.** `miggilcas/Onboard-SDK-ROS` ya trae
  `-DONBOARD_SDK_ROS_ONLY_INTERFACES=ON` (desde `2fceba8`): sin nodos, `modules` como librería INTERFACE, sin buscar
  el OSDK, LibUSB/FFMPEG opcionales. Mismo modelo que `psdk_ros2`: el contrato `images/msgs/noetic.repos` apunta a
  Onboard-SDK-ROS (`d7ee4b4`); `bridge:noetic` lo compila con la opción, y los dispositivos OSDK lo compilan completo
  con el Onboard-SDK instalado (`118e2825`). Un repo, un commit, un nombre: nada que se pueda desincronizar.
  **Sin verificar compilando**: `modules/CMakeLists.txt` hace `add_dependencies(${PROJECT_NAME} INTERFACE ...)`,
  que según la versión de CMake puede fallar. Es lo primero que hay que probar en R2.
- **Mensajes ROS 1 en transición**: el contrato noetic lleva `aerialcore_common` (flota actual) Y `multiuav_interfaces`.
  Se saca `aerialcore_common` cuando ningún dron ni interfaz del GCS lo use.
- **Credenciales DJI del M300 (confirmado: SON credenciales)**: `~/work/M300/app_ros2/psdk_ros2/psdk_wrapper/cfg/`
  tiene cambios sin commitear (`link_config.json`, `psdk_params.yaml`, `dji_sdk_config.json`). NUNCA a git ni al
  fork: en `devices/m300/` solo va un `.example` con los valores vacíos, y el real se añade al `.gitignore` antes
  de copiar nada. Mismo trato que `dji_psdk_config.json` y `UserConfig_*.txt`. Verificar con `git status` antes de
  cada commit de R1.
- **px4_msgs: el GCS no está alineado con la decisión 15** (confirmada 2026-10-31). `images/msgs/humble.repos` fija
  `v1.15.4`, pero el GCS espera `main`: `server/config/devices/interfaces/px4_ros2.yaml` suscribe a
  `vehicle_status_v4`, `battery_status_v1`, etc. (no existen en 1.15) y `infra/external.md` › Versiones de mensajes
  de PX4 pone el `px4_msgs` del rosbridge en `main`. Hasta adaptar el GCS (fuera de este repo), la interfaz
  `px4_ros2` no funciona contra `bridge:humble`. El translation node a bordo debe traducir HACIA 1.15 (v0).
- **`MUAV_GCS_interfaces` (resuelto 2026-10-31)**: el checkout de desarrollo es
  `~/ros2_px4_ws/src/work/MUAV_GCS_interfaces` (Jazzy), no el de `px4_ros2_docker` (que quedó en `4a8ffcc`). Contrato
  Humble subido a `59ebddf` (pusheado). Neto respecto de `4a8ffcc`: `OffboardCommand` msg/ack/srv nuevos (los pide
  `px4_ros2.yaml:63`) y `Mission.finish_action` con default 1 (go home). `GCSCommand`/`GCSCommandAck` sin cambios de
  contenido. Compatible en el cable: los defaults no viajan y el type hash de Jazzy los excluye
  (`rosidl_generator_type_description.calculate_type_hash`). El M300 no usa `Mission`. En R3: MISMO commit en `jazzy.repos`.
- **Registry**: por ahora build local. Publicar en GHCR cuando haya más usuarios.
- **README.md**: reescribirlo con el mapa del sistema al terminar R1.

## Mapa de esta máquina (relevado 2026-10-31)

Rutas de la máquina de desarrollo (`grvc`), para quien ejecute el plan. Al cerrar el plan se borra esta sección:
las rutas pasan a un `local.env` gitignored (patrón de `multiuav_gcs/infra/local.env`).

**Regla de alcance: SOLO se modifica `/home/grvc/work/multiUAV_system`.** Todo lo demás se lee y se copia, no se
edita ni se commitea.

### Este repo

| Ruta | Remote | Rama / versión |
|---|---|---|
| `/home/grvc/work/multiUAV_system` | `alvcaballero/multiUAV_system` | `refactor/rename-packages` (`d0dd48a`); default `main` |
| `…/multiUAV_system/multiuav_gui` (submódulo GCS) | `alvcaballero/multiuav_gui` | `7d4b1df` (`v1.4-184`) |
| `…/multiUAV_system/onboard_dji` (submódulo) | `alvcaballero/onboard_dji` | `refactor/rename-packages` (`66b809e`) |
| `…/multiUAV_system/onboard_px4` (submódulo) | `alvcaballero/onboard_px4` | `refactor/rename-pkgs` (`249a32c`) |

### Entorno ROS 1 actual (Noetic)

| Ruta | Qué es | Remote / versión |
|---|---|---|
| `/home/grvc/work/multiUAV_system/docker/` | Dockerfiles gcs/sim + `container_run.sh` (imágenes `muavgcs:ros1-gcs`, `muavgcs:ros1-sim`) | — |
| `/home/grvc/work/ros_docker_volume` | Volumen montado en `/app` del contenedor (NO es repo) | — |
| `…/ros_docker_volume/Onboard-SDK` | DJI OSDK, compilado con cmake | `dji-sdk/Onboard-SDK` `master` (`4.1.0-34`) |
| `…/catkin_ws/src/multiUAV_system` | Clon de ESTE repo, otra versión | `main` (`v1.2-16-gac7f051`) |
| `…/catkin_ws/src/Onboard-SDK-ROS` | `dji_osdk_ros` (msgs + nodos) | `miggilcas/Onboard-SDK-ROS` `dev` (`d7ee4b4`) |
| `…/catkin_ws/src/grvc-utils` | `mission_lib` (PX4 mavros) | `arpoma16/grvc-utils` `noetic` |
| `…/catkin_ws/src/robofleet_client` | — | `arpoma16/robofleet_client` `master` |
| `…/catkin_ws/src/{ros_rtsp,simple_vs}` | Vídeo | `CircusMonkey/ros_rtsp`, `miggilcas/simple_vs` |
| `…/catkin_ws/src/multiUAV_system/multiuav_gui/launch/connect_uas.launch` | El que lanza el compose del GCS (`roslaunch aerialcore_gui connect_uas.launch`): vive en el GCS VIEJO, submódulo del clon de `main` | hosts con `M300-NS-15`; la copia de `multiuav_bringup/launch/` tiene `nvidia2` |

### M300 (Jetson Orin Nano, L4T r36.4)

| Ruta | Qué es | Remote / versión |
|---|---|---|
| `/home/grvc/work/multiUAV_system/multiuav_bringup/devices/M300/` | Docker versionado del M300: opencv → ros1/ros2 → osdk/psdk (`docker/container_build.sh`) | este repo |
| `/home/grvc/work/M300` | Carpeta NO versionada con lo que va a bordo | — |
| `/home/grvc/work/M300/app_ros1/docker` | Copia vieja del docker del M300 (`docker2/`, `try2/`: restos) | — |
| `/home/grvc/work/M300/app_ros1/Readme.md` | Noetic en Jetson vía `jetson-containers` | — |
| `/home/grvc/work/M300/app_ros1/{multiUAV_system,ros_rtsp,simple_vs}` | Clones del lado ROS 1 | GitHub |
| `/home/grvc/work/M300/app_ros2/M300-PSDK-ROS2.yml` | tmuxinator del M300 PSDK | — |
| `/home/grvc/work/M300/app_ros2/{camera_file_downloader,camera_rtsp_bridge,missions}` | Utilidades a bordo, sin repo | — |
| `/home/grvc/work/M300/app_ros2/psdk_ros2` | **Upstream** `umdlife/psdk_ros2` `feat/waypoint-v2` (`18e6967`), con config local sin commitear | NO es el fork |
| `/home/grvc/work/M300/app_ros2/{MUAV_GCS_interfaces,MUAV_psdk_offboard}` | Remote `ssh://grvc@10.20.0.2/…/px4_ros2_docker/…` | Atrasados respecto de `px4_ros2_docker` (sus commits ya están allí: no hay trabajo perdido) |

### Entorno ROS 2 (Humble / Jazzy, PX4, PSDK)

| Ruta | Qué es | Remote / versión |
|---|---|---|
| `/home/grvc/work/px4_ros2_docker` | Entorno Humble + PX4 1.15.4. Modelo de organización a seguir. `.repos` en la raíz | `arpoma16/px4_ros2_docker` `compose2` (`af19992`) |
| `…/px4_ros2_docker/Docker/` | `px4_gz`, `ros2`, `ros2_microdds`, `ros2_ws`, `ros_gz` Dockerfiles | — |
| `…/px4_ros2_docker/psdk_ros2` | **El fork** (decisión 14) | `arpoma16/psdk_ros2` `dev/integration` (`1.3.2-40`) |
| `…/px4_ros2_docker/px4_msgs` | Contrato PX4 (decisión 15) | `PX4/px4_msgs` `release/1.15` (`v1.15.4`) |
| `…/px4_ros2_docker/MUAV_GCS_interfaces` | Mensajes del GCS (ROS 2) | `arpoma16/MUAV_GCS_interfaces` `main` (`4a8ffcc`) |
| `…/px4_ros2_docker/MUAV_psdk_offboard` | Nodo a bordo PSDK | `arpoma16/MUAV_psdk_offboard` `main` (`cdcffa5`) |
| `…/px4_ros2_docker/{MUAV_GCS_gz,MUAV_GCS_offboard,MUAV_psdk_gz}` | Sim y offboard | `arpoma16/*` `main` |
| `/home/grvc/ros2_px4_ws` | Workspace Jazzy (PX4 + MQTT) | `src/work` = otro clon de `px4_ros2_docker` (`compose2`, `085f11b`) |
| `…/ros2_px4_ws/src/work/MUAV_GCS_interfaces` | **Checkout de desarrollo de los mensajes del GCS** (Jazzy) | `arpoma16/MUAV_GCS_interfaces` `main`, 2 commits sin pushear + cambios sin commitear |
| `/home/grvc/PX4-Autopilot` | Firmware PX4 en el host | `main` (`v1.18.0-beta1-956`) — NO es el contrato |

### GCS y servicios (solo lectura)

| Ruta | Qué es | Remote / versión |
|---|---|---|
| `/home/grvc/work/px4/llm_planner_gcs` | Repo paraguas LLM planner | `arpoma16/LLM_MUAV_Planner_GCS` `main` |
| `/home/grvc/work/px4/llm_planner_gcs/multiuav_gcs` | **Checkout de desarrollo del GCS** | `alvcaballero/multiuav_gui` `feat/eve-agent-integration` (`v2.0-207-g14075b8`) |
| `…/multiuav_gcs/infra/` | Compose del GCS; `compose.ros1.yaml` usa `muavgcs:ros1`, `compose.ros2.yaml` `muavgcs:ros2` | — |
| `…/multiuav_gcs/infra/external.md` | Qué mensajes y versiones espera el GCS por interfaz | — |
| `…/multiuav_gcs/infra/repos/*.repos` | `.repos` del GCS (se reemplazan por los de este repo, fuera de este plan) | — |
| `…/multiuav_gcs/server/config/devices/interfaces/` | `messageType` de cada interfaz: lo que el bridge debe poder deserializar | — |
| `…/multiuav_gcs/infra/local.env` | Rutas locales del GCS | gitignored |
| `/home/grvc/work/px4/llm_planner_gcs/{mcp_server,Smart-Flies-MUAVPlanner}` | MCP y planner (imagen `muavgcs:planner`) | submódulos |

### Imágenes Docker en esta máquina

`muavgcs:noetic` (5.46 GB, la que hace de bridge ROS 1; el compose espera `muavgcs:ros1`), `ros2-px4-ws:humble`,
`ros2-px4:humble`, `ros2-microdds:humble`, `ros2-desktop:humble`, `ros:humble`, `muav-arducopter-sitl:4.7.2`.
Las imágenes Jetson del M300 (`opencv-cuda`, `ros-humble-psdk`, `ros-noetic-osdk` `:l4t-r36.4.0`) se construyen
EN el Jetson, no aquí.

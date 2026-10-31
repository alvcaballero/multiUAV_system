# Plan: entornos ROS del sistema (GCS, dispositivos, desarrollo)

Estado (2026-10-31): **R1, R2 y R3 escritos y pusheados, NADA construido ni probado. Sigue: la verificación del
usuario (abajo); con eso, cerrar el plan.**
Rama: `refactor/rename-packages` (desde `d0dd48a`; `git log` para el HEAD).

Alcance: SOLO este repo (`/home/grvc/work/multiUAV_system`). Los demás repos se LEEN y se referencian por `.repos`,
no se editan ni se commitean. Si hace falta un cambio en otro repo, se anota en "Fuera de este repo".

## Para retomar (leer primero)

1. `git log --oneline d0dd48a..HEAD`: qué se hizo, un commit por paso.
2. Este plan: decisiones (no se re-discuten), estado y verificación pendiente.
3. `README.md` (mapa) y `devices/<x>/README.md` (cada dispositivo).
4. Reglas que se aplicaron en todo R1/R2 y siguen en R3:
   - Versiones fijadas por **commit** en los `.repos` (tag si existe); verificar con `git ls-remote` que el commit
     esté en GitHub, no solo en un checkout local (los locales suelen estar atrasados o con commits sin pushear).
   - Un dispositivo compila SOLO lo que piden sus paquetes (`--packages-up-to` / `--only-pkg-with-deps`).
   - Credenciales: solo `.example` en git; lo real en `devices/<x>/cfg/` (gitignored). Nunca imprimirlas: comparar
     por hash/largo.
   - Verificar sin construir cuando el usuario no lo pide: `colcon list` sobre los `.repos` reales en un contenedor
     descartable, `rosdep check`, `docker build --check` (con bases públicas de reemplazo), `bash -n`, render de
     tmuxinator con ruby/ERB, dobles de prueba para scripts.
   - Commits en grupos lógicos (conventional commits, sin atribución a IA) y push al terminar cada paso.

## Decisiones

1. **Este repo es el sistema**: entornos, dispositivos y el contrato de mensajes. Sin paquetes ROS propios: el
   código entra por `.repos`.
2. **Una carpeta por dispositivo con TODO lo suyo** (Dockerfile, `.repos`, tmuxinator, README, `cfg/*.example`,
   `host/`). Lo compartido entre roles va en `images/`; lo compartido entre drones, en `devices/common/`.
3. **Carpetas por distro, NO ramas por distro** (en ESTE repo). El GCS necesita bridges de varias distros a la vez.
4. **Un bridge por distro** (`noetic`, `humble`, `jazzy`). Probado: Humble↔Jazzy no se entienden bien.
5. **El contrato = `images/msgs/<distro>.repos`**: lo que el BRIDGE tiene que deserializar (la unión). Un mensaje
   nuevo se declara UNA vez.
6. **El contrato es el ARCHIVO, no la imagen.** `bridge` y `dev` heredan `muav/msgs:<distro>`. Los dispositivos
   importan el `.repos` con vcs dentro de su propia imagen y compilan **solo lo que declaran sus `package.xml`**, en la
   versión del contrato (el M300 PSDK no compila `px4_msgs`).
7. **`dji_osdk_ros`: el mismo `Onboard-SDK-ROS` en todos lados.** El bridge lo compila con
   `-DONBOARD_SDK_ROS_ONLY_INTERFACES=ON` (sin nodos ni Onboard-SDK); los drones OSDK, completo. El nombre de paquete
   no cambia (rosbridge carga por `paquete/Mensaje`, ROS 1 compara MD5).
8. **Mensajes del GCS en ROS 1: rama HUÉRFANA `ros1` de `arpoma16/MUAV_GCS_interfaces`** (catkin; `main` es ROS 2). No
   se mergean nunca. Lleva `aerialcore_common` (la flota y las interfaces del GCS lo piden) y `multiuav_interfaces`
   (nombre nuevo), idénticos byte a byte, mientras la flota migra.
9. **`multiuav_bringup` se vació hacia `devices/` y se borró** (hecho).
10. **`connect_uas.launch` → `images/bridge/`**, hosts por `MUAV_HOSTS`. `images/bridge/multimaster.launch` es el
    MISMO archivo para el GCS y los drones: cada lado lista al OTRO.
11. **El GCS sigue como submódulo (`multiuav_gui`) = "última versión verificada"**; su desarrollo va en su checkout.
12. **Versiones con tag o commit, nunca rama.**
13. **Desarrollo: `dev:<distro>` con el bridge dentro** (`/opt/muav/bridge/start.sh`) y los mismos mensajes.
14. **`psdk_interfaces`/`psdk_wrapper` del fork `arpoma16/psdk_ros2`**, nada por apt.
15. **PX4: contrato Humble en `px4_msgs` `v1.15.4`** (confirmado por el usuario). Otra versión de PX4 a bordo → el
    translation node de PX4, no otro contrato. OJO: el GCS espera `main` (ver "Fuera de este repo").
16. **Un `.repos` por distro también en los dispositivos** (`devices/<x>/<distro>.repos`). El M300 tiene
    `humble.repos` (PSDK) y `noetic.repos` (OSDK); sin Jazzy (L4T r36.4 = Ubuntu 22.04, Jazzy solo tiene apt en 24.04).
17. **colcon compila también los paquetes catkin**: un solo `images/msgs/Dockerfile` para las tres distros.
18. **M600 fuera** (no se usa). **Melodic fuera** (todos los M210 en Noetic).
19. **Contrato Jazzy: `px4_msgs` @`6cdc4f5`** (en `main` de GitHub; "Update to PX4 f629d451"). Es lo que corre en
    `~/ros2_px4_ws` y coincide con lo que el GCS escucha (`vehicle_status_v4`, `battery_status_v1`,
    `vehicle_local_position_v1`, `vehicle_command_ack_v1`). NO `main`: el 2026-10-30 (`83cd992`) pasó a
    `VehicleStatus` v5 / `VehicleCommandAck` v2. Ningún tag sirve (`v1.17.0` tiene `VehicleStatus` v1). Confirmado por
    el usuario.
20. **Micro-XRCE-DDS Agent `v2.4.3`** (el del `.repos` del GCS y del workspace Jazzy local). Confirmado por el usuario.
21. **Sin mock ROS 2 en R3**: el SITL de `dev:jazzy` hace de dron. Queda para después.
22. **Dev: el workspace ENTERO en el host, montado siempre en `/ws`** (`install/` guarda rutas absolutas). Ruta por
    `MUAV_WS_<DISTRO>` (una por distro), por defecto `ws/<distro>`. Terminal y VS Code (`.devcontainer/jazzy{,-nvidia}`)
    usan la misma imagen y el mismo `/ws`; con el devcontainer en marcha, `container_run.sh dev` entra en él (un solo
    entorno). Confirmado por el usuario (A+B+D; usa devcontainer, tmux y terminal).

## Estructura actual

```
images/                  base/ msgs/ bridge/ dev/ (+ dev/mock/, dev/tmuxinator_px4{,_ros2}_sim.yml), build.sh
  msgs/noetic.repos      MUAV_GCS_interfaces ros1 @4c09d61 + Onboard-SDK-ROS @d7ee4b4
  msgs/humble.repos      MUAV_GCS_interfaces @59ebddf + psdk_ros2 @8b65dd5 + px4_msgs v1.15.4
  msgs/jazzy.repos       MUAV_GCS_interfaces @59ebddf + px4_msgs @6cdc4f5
devices/
  common/                osdk/{install_osdk.sh,entrypoint_osdk.sh}, multimaster_watch.sh, boot/ (hora desde el GCS)
  m300/                  Jetson L4T r36.4: opencv → ros2 → psdk (Humble) | opencv → ros1 (fuentes) → osdk (Noetic)
  m210/                  Raspberry Pi, Noetic sobre muav/base:noetic
  vtol/                  Raspberry Pi, PX4 por mavros, Noetic sobre muav/base:noetic
  px4_ros2/              PX4 uXRCE-DDS, Jazzy sobre muav/base:jazzy; px4.env = el PX4 del contrato (f629d451)
container_run.sh         dev|bridge <distro> | <dispositivo> ...
ws/<distro>/             gitignored, montado en /ws de dev
multiuav_gui/            submódulo GCS (7d4b1df)
```

Tags de imagen: `muav/<rol>:<distro>` (x86 y multi-arch), `muav/m210:noetic`, `muav/vtol:noetic`,
`muav/px4_ros2:jazzy`; Jetson:
`opencv-cuda`, `ros-humble`, `ros-humble-psdk`, `ros-noetic`, `ros-noetic-osdk` `:l4t-r36.4.0`.

## Estado por rebanada

### R1 — Humble + M300 PSDK: escrito, sin construir
- `images/*` Humble, `devices/m300` perfil PSDK (`humble.repos`: `MUAV_psdk_offboard` @`bb5c074`).
- `psdk_wrapper` lee las credenciales de sus parámetros ROS: `cfg/psdk_params.yaml` + `cfg/link_config.json`.
- Falta: **paso 5**, que el GCS reciba la telemetría PSDK por `bridge:humble`.

### R2 — Noetic + M300 OSDK / M210 / VTOL: escrito, sin construir; limpieza hecha
- `images/*` Noetic (bridge con multimaster apt 1.3.2; dev con Onboard-SDK, mavros y PX4 v1.14.4 SITL + Gazebo 11
  compilado en la imagen; drones falsos `images/dev/mock/` para ver el GCS sin hardware).
- `devices/m300` OSDK, `devices/m210`, `devices/vtol`, `devices/common`. Detalles en cada README.
- Limpieza: borrados `docker/`, `multiuav_bringup/`, `multiuav_interfaces/`, submódulos `onboard_*` (commit
  `906bfb1`; lo viejo sigue en `906bfb1^` si hace falta). Credenciales locales movidas sin abrir a
  `devices/m300/cfg/` (`UserConfig_osdk.txt`) y `devices/m300/cfg/legacy/` (las 2 de PSDK en formato viejo: pasarlas a
  mano a `psdk_params.yaml` y `link_config.json`).

### R3 — Jazzy + PX4 ROS 2: escrito, sin construir
- `images/msgs/jazzy.repos` (decisión 19). `bridge:jazzy` sin cambios (genérico).
- `devices/px4_ros2`: Agent `v2.4.3` + `MUAV_px4_offboard` @`6864e57` + `mqtt_client` @`cb43b6c` (`jazzy.repos`) +
  translation node de PX4 `f629d451` (`px4.env` + `fetch_translation_node.sh`: un commit, dos carpetas, 440 KB).
  Solo perfil Jazzy (no Humble): el offboard compilado contra `px4_msgs` v1.15.4 le mandaría al GCS la estructura vieja.
- `dev:jazzy`: Agent en `/opt/muav/tools` (nueva capa de `muav_env.sh`) del MISMO `jazzy.repos`; PX4 SITL de
  `px4.env` + Gazebo Harmonic (`ubuntu.sh`) + `ros-jazzy-ros-gz`; `images/dev/tmuxinator_px4_ros2_sim.yml`.
- `bridge` (todas las distros): `--ipc host`, igual que `dev`. Sin eso, Fast-DDS entre contenedores del mismo host
  descubre pero no recibe datos.
- Verificado sin construir: `colcon list` y `rosdep install -s` sobre los `.repos` reales en `ros:jazzy-ros-base` (todas las
  claves resuelven; entran exactamente 8 paquetes), `docker build --check` (base pública), render ERB de los dos
  tmuxinator, `bash -n`, `fetch_translation_node.sh` corrido de verdad. `px4_msgs` `6cdc4f5` == `msg/`+`srv/` de PX4
  `f629d451` (diff vacío). `UXRCE_DDS_NS_IDX`/`PX4_UXRCE_DDS_NS` → `uav_<n>`, SITL instancia 0 → sysid 1, UDP 8888
  (leído en `rcS` y `uxrce_dds_client.cpp` de ese commit).

### Verificación pendiente de R1+R2+R3 (la hace el usuario; si algo falla, se arregla en la sesión)
1. `images/build.sh humble` y `images/build.sh noetic` (x86). Lo primero que puede fallar: `dji_osdk_ros` con
   `ONLY_INTERFACES` (`modules/CMakeLists.txt` hace `add_dependencies(${PROJECT_NAME} INTERFACE ...)`).
2. `./container_run.sh dev noetic` → `roscore & /opt/muav/bridge/start.sh & /opt/muav/mock/mock_fleet.sh`: el GCS
   debe ver 4 drones.
3. Jetson: `devices/m300/container_build.sh` (horas: OpenCV CUDA) y los dos tmuxinator.
4. Pi: `images/build.sh noetic base`, `devices/m210/container_build.sh`, `devices/vtol/container_build.sh`.
5. Telemetría real en el GCS por `bridge:humble` (PSDK) y `bridge:noetic` (OSDK, PX4 mavros).
6. `images/build.sh jazzy` (x86; `dev` compila PX4: lo primero que puede fallar es `ubuntu.sh` dentro de Docker o
   `make px4_sitl` sin GPU). Luego `tmuxinator_px4_ros2_sim.yml` + `bridge:jazzy` o el bridge de dev: el GCS debe ver
   `uav_1` (interfaz `px4_ros2`).
7. Companion: `images/build.sh jazzy base`, `devices/px4_ros2/container_build.sh`, `tmuxinator.yml id=<n>` con el
   firmware en `UXRCE_DDS_NS_IDX=<n>`.
8. Devcontainer: `export MUAV_WS_JAZZY=$HOME/ros2_px4_ws`, VS Code → *Reopen in Container* → `jazzy-nvidia`. Terminal
   zsh con `ros2` cargado, `/opt/muav/ws_rosdep.sh` corrido, `gz sim` abre la GUI; después `./container_run.sh dev
   jazzy` desde tmux debe decir "devcontainer de VS Code en marcha".

## Después del plan (no entra en R1–R3)

- Mock ROS 2 (PSDK / PX4 ROS 2) para `dev`: `images/dev/mock/` es solo ROS 1 (decisión 21).
- Dev como el usuario del host (`--user`), para que `/ws` no se llene de archivos de root: hay que crear el usuario en la
  imagen y mover lo que asume `/root` (`.bashrc`, rosdep, apt). Tocar `images/base`, después de verificar.
- Devcontainer de `noetic`/`humble`: copiar `.devcontainer/jazzy*` cambiando la distro (si se usa).
- `dev:humble` sin SITL: el contrato Humble es PX4 `v1.15.4`; si hace falta, mismo patrón que Jazzy con ese tag.
- Subir el contrato Jazzy cuando salga un PX4 nuevo: `images/msgs/jazzy.repos` (`px4_msgs`) y
  `devices/px4_ros2/px4.env` JUNTOS, los topics de `px4_ros2.yaml` del GCS y `config/topics.yaml` del offboard.

## Fuera de este repo (pendientes del usuario o de otros repos)

**Seguridad (urgente)** — borrar los archivos no saca los secretos de la historia de git:
1. Credenciales DJI en `miggilcas/Onboard-SDK-ROS` (público), `launch/dji_vehicle_node.launch` (incluido `d7ee4b4`):
   rotar en el portal DJI y avisar al dueño. El `entrypoint_osdk.sh` las pisa al arrancar.
2. Credenciales DJI de OTRA app en `alvcaballero/onboard_dji` (público), rama `M210`, `launch/atlas-noetic.launch`:
   rotar.
3. Contraseñas WiFi (3) en la historia de ESTE repo (público): `multiuav_bringup/devices/M300/Netplan.yaml` y
   `M210/50-cloud-init.yaml`: cambiarlas en los routers.

GCS (`multiuav_gcs`):
- `infra/compose/compose.ros1.yaml` sobreescribe el `command` con `roslaunch aerialcore_gui connect_uas.launch`:
  quitarlo y pasar `MUAV_HOSTS` para usar `muav/bridge:noetic`. Igual para `compose.ros2.yaml` → `muav/bridge:<distro>`.
- `px4_ros2.yaml` coincide con el contrato JAZZY (`px4_msgs` `6cdc4f5`). Con `bridge:humble` (`v1.15.4`, decisión 15)
  no: PX4 ROS 2 va por `bridge:jazzy`.
- `infra/repos/ros2_px4.repos` fija por RAMA y ya está roto: `px4_msgs` `main` pasó a `VehicleStatus` v5 el
  2026-10-30. Reemplazar por `images/msgs/jazzy.repos` + `devices/px4_ros2/jazzy.repos` de este repo.
- `infra/external.md` dice "`px4_msgs` `main` (= PX4 1.18)" y "PX4-Autopilot `main`": pasar a `6cdc4f5` / `f629d451`.
- `infra/repos/` y la parte de mensajes de `infra/external.md` → citar este repo. `infra/local.env` con una sola
  `MUAV_SYSTEM_DIR`.
- Actualizar el puntero del submódulo `multiuav_gui` (hoy `7d4b1df`) tras probar el conjunto.

Otros:
- `MUAV_px4_offboard` (`~/ros2_px4_ws/src/work`): 4 archivos modificados sin commitear (`bt/commands.py`,
  `bt/offboard_mission_bt.py`, `config/bt_mission.yaml`, `docs/gcs_commands.md`) NO están en el pin `6864e57`.
- `wirispro_manager` (`miggilcas`, privado o borrado): mientras no sea accesible, el VTOL usa `onboard_px4` `main`, sin
  el servicio de la WIRIS Pro (`feature/wirispro` depende de él).
- `onboard_px4` `atlas.launch`: `fcu_url` y `gcs_url` (`udp://@192.168.0.123:14550`) escritos, sin argumentos.
- `onboard_dji` rama `M210`: 60 commits sin mergear en `main`.
- Registry: por ahora build local; GHCR cuando haya más usuarios.

## Trampas conocidas (verificadas)

- **rosdep + Noetic EOL**: `rosdep update` sin `--include-eol-distros` BORRA Noetic del caché y deja de resolver
  claves (`nmea_msgs`…). `images/base` lo hace bien y deja el alias `rosdep-update`.
- `ros:noetic-ros-base` no trae `git`: en pruebas con `vcs import`, instalarlo (la imagen `base` sí lo trae).
- `px4_bringup` (grvc-ual) declara `gazebo_ros` como run_depend: en drones, `rosdep --skip-keys gazebo_ros`.
- ROS 1: dos nodos con el mismo nombre se echan entre sí (`__name:=` único).
- `ros_rtsp` lee su config de `$(find ros_rtsp)/config/stream_setup.yaml` sin argumento: se monta encima.
- `simple_vs` `main` arma el namespace como `uav_<id>`: pasar el NÚMERO (`uav_id:=2`).
- Bash: un `trap` en INT/TERM que no hace `exit` deja vivo el bucle del script.
- `px4_msgs` `main` NO es una versión: cambia la estructura sin aviso (2026-10-30: `VehicleStatus` v4 → v5). Siempre
  por commit, y el mismo PX4 en `px4.env`.
- PX4 `Tools/copy_to_ros_ws.sh` pisa los `.msg` de `px4_msgs` con los del firmware: no usarlo sobre el contrato.
- PX4 `Tools/setup/ubuntu.sh` usa `sudo` y NO detecta Docker solo (`RUNS_IN_DOCKER` lo pasa quien lo llama): las
  bases `ros:*` traen `sudo`, así que funciona sin esa variable.
- devcontainer.json NO anida variables: `${localEnv:X:${localWorkspaceFolder}/…}` sale roto (probado con el CLI
  `devcontainer read-configuration`). Defaults solo literales.
- Feature `common-utils` con `username: automatic` en Ubuntu 24.04 elige al usuario `ubuntu` (UID 1000) y deja root sin
  zsh: `username: none`. El devcontainer de `~/ros2_px4_ws/src/work` funcionaba porque Humble (22.04) no lo tiene, y
  su `devcontainer-nvidia.json` tiene mal la URL de `zsh-syntax-highlighting` (`zsh-users/zsh-users/…`).
- Un `.zshrc` no carga `setup.bash`: `muav_env.sh` elige `setup.zsh` o `setup.bash` según el shell.
- Micro-XRCE-DDS Agent fuera de colcon usa por defecto la superbuild (baja su propio Fast-DDS). Su `colcon.pkg` fuerza
  el de `/opt/ros`: compilarlo con colcon.

## Mapa de esta máquina (2026-10-31)

Al cerrar el plan, estas rutas pasan a un `local.env` gitignored (patrón de `multiuav_gcs/infra/local.env`).

| Ruta | Qué es | Remote / versión |
|---|---|---|
| `/home/grvc/work/multiUAV_system` | ESTE repo | `alvcaballero/multiUAV_system`, `refactor/rename-packages` |
| `~/work/px4/llm_planner_gcs/multiuav_gcs` | Checkout de desarrollo del GCS (solo lectura) | `alvcaballero/multiuav_gui` `feat/eve-agent-integration` |
| `…/multiuav_gcs/infra/{compose,repos,external.md}` | Lo que el GCS espera de los bridges y los drones | — |
| `…/multiuav_gcs/server/config/devices/interfaces/` | `messageType` por interfaz: lo que el bridge debe deserializar | — |
| `~/work/px4_ros2_docker` | Entorno Humble + PX4 1.15.4 (fuente para R3; checkouts ATRASADOS respecto de GitHub) | `arpoma16/px4_ros2_docker` `compose2` |
| `~/ros2_px4_ws/src/work` | Clon Jazzy de trabajo; `MUAV_GCS_interfaces` de desarrollo | `compose2` |
| `~/work/M300/app_ros{1,2}` | Lo que corría a bordo del M300 (ya relevado) | sin versionar |
| `~/work/ros_docker_volume` | Volumen del entorno ROS 1 viejo (reemplazado por `ws/` + `dev:noetic`) | sin versionar |
| `~/work/wirispro_manager` | Único checkout de `wirispro_manager` (`db7d5dd`) | remote inaccesible |
| `~/PX4-Autopilot` | Firmware PX4 del host, `main` — NO es el contrato | `PX4/PX4-Autopilot` |

Imágenes viejas aún en esta máquina (reemplazables cuando se pruebe lo nuevo): `muavgcs:noetic` (bridge ROS 1
actual), `ros2-px4-ws:humble`, `ros2-px4:humble`, `ros2-microdds:humble`, `ros2-desktop:humble`.

# Plan: entornos ROS del sistema (GCS, dispositivos, desarrollo)

Estado (2026-10-31): **R1 y R2 escritos y pusheados, NADA construido ni probado. Limpieza de R2 hecha. Sigue: R3.**
Rama: `refactor/rename-packages` (HEAD `02560bb`, 33 commits desde `d0dd48a`).

Alcance: SOLO este repo (`/home/grvc/work/multiUAV_system`). Los demás repos se LEEN y se referencian por `.repos`,
no se editan ni se commitean. Si hace falta un cambio en otro repo, se anota en "Fuera de este repo".

## Para retomar (leer primero)

1. `git log --oneline d0dd48a..HEAD`: qué se hizo, un commit por paso.
2. Este plan: decisiones (no se re-discuten), estado y el arranque de R3.
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

## Estructura actual

```
images/                  base/ msgs/ bridge/ dev/ (+ dev/mock/, dev/tmuxinator_px4_sim.yml), build.sh
  msgs/noetic.repos      MUAV_GCS_interfaces ros1 @4c09d61 + Onboard-SDK-ROS @d7ee4b4
  msgs/humble.repos      MUAV_GCS_interfaces @59ebddf + psdk_ros2 @8b65dd5 + px4_msgs v1.15.4
devices/
  common/                osdk/{install_osdk.sh,entrypoint_osdk.sh}, multimaster_watch.sh, boot/ (hora desde el GCS)
  m300/                  Jetson L4T r36.4: opencv → ros2 → psdk (Humble) | opencv → ros1 (fuentes) → osdk (Noetic)
  m210/                  Raspberry Pi, Noetic sobre muav/base:noetic
  vtol/                  Raspberry Pi, PX4 por mavros, Noetic sobre muav/base:noetic
container_run.sh         dev|bridge <distro> | <dispositivo> ...
ws/<distro>/             gitignored, montado en /ws de dev
multiuav_gui/            submódulo GCS (7d4b1df)
```

Tags de imagen: `muav/<rol>:<distro>` (x86 y multi-arch), `muav/m210:noetic`, `muav/vtol:noetic`; Jetson:
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

### Verificación pendiente de R1+R2 (la hace el usuario; si algo falla, se arregla en la sesión)
1. `images/build.sh humble` y `images/build.sh noetic` (x86). Lo primero que puede fallar: `dji_osdk_ros` con
   `ONLY_INTERFACES` (`modules/CMakeLists.txt` hace `add_dependencies(${PROJECT_NAME} INTERFACE ...)`).
2. `./container_run.sh dev noetic` → `roscore & /opt/muav/bridge/start.sh & /opt/muav/mock/mock_fleet.sh`: el GCS
   debe ver 4 drones.
3. Jetson: `devices/m300/container_build.sh` (horas: OpenCV CUDA) y los dos tmuxinator.
4. Pi: `images/build.sh noetic base`, `devices/m210/container_build.sh`, `devices/vtol/container_build.sh`.
5. Telemetría real en el GCS por `bridge:humble` (PSDK) y `bridge:noetic` (OSDK, PX4 mavros).

## R3 — Jazzy + PX4 ROS 2 (siguiente)

Objetivo: `images/{base,msgs,bridge,dev}` para Jazzy y `devices/px4_ros2` con `ARG ROS_DISTRO` (humble | jazzy).
Los Dockerfiles de `images/` ya son genéricos por distro: R3 es sobre todo el contrato, el dispositivo y el dev.

Datos ya relevados (no repetir):
- **`MUAV_GCS_interfaces`**: el MISMO commit que Humble (`59ebddf7a8ae7bc48241018f9880d75d57f4d307`). El GCS tiene
  una sola definición. Checkout de desarrollo: `~/ros2_px4_ws/src/work/MUAV_GCS_interfaces` (Jazzy).
- **`px4_msgs` en Jazzy: DECIDIR al empezar.** La decisión 15 fija `v1.15.4` para Humble; el GCS
  (`multiuav_gcs/infra/repos/ros2_px4.repos` y `server/config/devices/interfaces/px4_ros2.yaml`) usa `main` y topics
  versionados (`vehicle_status_v4`, `battery_status_v1`) que NO existen en 1.15. Preguntar al usuario si Jazzy sigue
  la decisión 15 o va a `main`.
- **Micro-XRCE-DDS Agent: versiones distintas.** `px4_ros2_docker/Docker/ros2_microdds.Dockerfile` compila `v3.0.1`;
  el `.repos` del GCS dice `v2.4.3`. Elegir una al empezar.
- Lo que el GCS espera a bordo en Jazzy (`multiuav_gcs/infra/repos/ros2_px4.repos`, por rama: hay que FIJAR):
  `px4_msgs`, `Micro-XRCE-DDS-Agent`, `MUAV_GCS_interfaces`, `arpoma16/mqtt_client` (`muav/service-bridge`, protocolo
  mqtt), `arpoma16/MUAV_px4_offboard` (`main`).
- **Translation node** de PX4 (`PX4-Autopilot/msg/translation_node`): uno por dron, con su namespace; compilar desde
  un PX4 igual o más nuevo que el más nuevo de los dos lados (`multiuav_gcs/infra/external.md` › Versiones de
  mensajes de PX4). Los servicios no se traducen en Humble.
- Fuente a copiar (no tocar): `~/work/px4_ros2_docker` (`Docker/{ros2,ros2_microdds,px4_gz,ros2_ws,ros_gz}.Dockerfile`,
  `.repos`, `tmuxinator/`). Clon Jazzy de trabajo: `~/ros2_px4_ws/src/work` (`compose2`).
- `images/dev/Dockerfile` ya maneja ROS 2 (`ros-dev-tools`). Para PX4 en Jazzy: Gazebo Harmonic (`ros-gz`), no
  Gazebo Classic: ver `px4_gz.Dockerfile` y `ros_gz.Dockerfile`.
- `images/dev/mock/` es solo ROS 1. Un mock ROS 2 (PSDK / PX4 ROS 2) sería trabajo nuevo, si se quiere.

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
- `px4_ros2.yaml` espera `px4_msgs` `main`; el contrato Humble es `v1.15.4` (decisión 15): alinear uno de los dos.
- `infra/repos/` y la parte de mensajes de `infra/external.md` → citar este repo. `infra/local.env` con una sola
  `MUAV_SYSTEM_DIR`.
- Actualizar el puntero del submódulo `multiuav_gui` (hoy `7d4b1df`) tras probar el conjunto.

Otros:
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

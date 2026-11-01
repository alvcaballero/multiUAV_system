# AGENTS.md: multiUAV_system

Instrucciones para agentes de código (Claude Code, Codex, Copilot…) que trabajan en este repo.

## Qué es este repo

**Es el sistema**: los entornos Docker del GCS, de desarrollo y de cada dron, y el **contrato de mensajes** que
comparten. NO tiene paquetes ROS propios: el código entra por archivos `.repos` (vcstool), fijado por commit.

Leé en este orden antes de cambiar algo:

1. [`README.md`](README.md): el mapa y el uso.
2. [`docs/plans/environments.md`](docs/plans/environments.md): decisiones numeradas (NO se re-discuten sin el
   usuario), estado, verificación pendiente, "Fuera de este repo" y **Trampas conocidas** (verificadas).
3. `devices/<x>/README.md` del dispositivo que toques.

## Mapa

```
images/                  compartido, un Dockerfile por rol con ARG ROS_DISTRO (noetic | humble | jazzy)
  base/                  ROS + colcon + vcstool; muav_env.sh carga el entorno en capas (bash y zsh)
  msgs/<distro>.repos    EL CONTRATO: los mensajes que el bridge del GCS tiene que deserializar
  bridge/                rosbridge del GCS (+ multimaster en noetic)
  dev/                   desarrollo: herramientas + PX4 SITL + Gazebo; el código va en /ws (host)
  build.sh <distro>      base → msgs → bridge → dev (y genera el devcontainer)
devices/<x>/             un dron por carpeta con TODO lo suyo: Dockerfile, <distro>.repos, tmuxinator, README, cfg/,
                         SETUP.md (conexión de hardware + puesta en marcha)
  m300/                  dos perfiles: base/ (OpenCV CUDA), psdk/ y osdk/ (cada uno con su SETUP.md), host/
  m210/ vtol/ px4_ros2/ common/
.devcontainer/           plantilla + generate.sh; <distro>/ es generado y gitignored
container_run.sh         dev | bridge <distro>, o un dispositivo
ws/<distro>/             workspaces de desarrollo (gitignored), montados en /ws
multiuav_gui/            GCS (submódulo): tiene su propio CLAUDE.md
```

| Distro | Para qué | Dispositivos |
|---|---|---|
| noetic | ROS 1: DJI OSDK, PX4 por mavros | M300 OSDK, M210, VTOL |
| humble | DJI PSDK (`psdk_ros2` NO funciona en Jazzy), PX4 1.15 | M300 PSDK |
| jazzy | PX4 por uXRCE-DDS | `px4_ros2` |

## Reglas

**Alcance**
- Solo se edita y se commitea ESTE repo. Los demás (GCS, `~/ros2_px4_ws`, `~/work/px4_ros2_docker`, repos de los
  `.repos`) se LEEN; si necesitan un cambio, se anota en "Fuera de este repo" del plan.
- `multiuav_gui` es un submódulo = "última versión verificada" con este sistema: no muevas su puntero salvo pedido
  explícito, aunque `git status` lo muestre modificado.

**Versiones**
- Todo `.repos` se fija por **commit completo** (o tag si existe), nunca por rama. Comentario al lado con la rama de
  origen (`# main`).
- Antes de fijar: verificá que el commit esté en GitHub (`git ls-remote`, `gh api repos/<o>/<r>/commits/<sha>`). Los
  checkouts locales suelen estar atrasados o tener commits SIN pushear: un pin a un commit local no le sirve a nadie.
- Un mensaje nuevo se declara UNA vez, en `images/msgs/<distro>.repos`. El contrato PX4 de Jazzy son dos archivos
  que se suben JUNTOS: `px4_msgs` en `images/msgs/jazzy.repos` y el commit de PX4 en `devices/px4_ros2/px4.env`.
- Un dispositivo compila SOLO lo que piden sus `package.xml` (`--packages-up-to` / `--only-pkg-with-deps`).

**Guías de hardware (`SETUP.md`)**
- Mismo orden en todas: materiales → conexión → firmware/dron → host → software → arranque → verificación → problemas.
- Solo datos con fuente (docs del fabricante, código, configs del repo, confirmación del usuario). Lo que no está
  relevado va como `⚠ A COMPLETAR` / `⚠ A CONFIRMAR`, nunca inventado: un pinout o una tensión equivocados
  queman hardware.

**Credenciales**
- Solo `cfg/*.example` va a git; lo real vive en `devices/<x>/cfg/` (gitignored). Nunca imprimas una credencial:
  compará por hash o largo.

**Construir y verificar**
- NO construyas imágenes salvo que el usuario lo pida: tardan horas (PX4, OpenCV CUDA). Verificá sin construir:
  - `colcon list` y `rosdep install -s` sobre los `.repos` reales, en un contenedor descartable (`ros:<distro>-ros-base`);
  - `docker build --check` con `--build-arg BASE_IMAGE=ros:<distro>-ros-base` (las `muav/*` pueden no existir);
  - `bash -n` y `shellcheck`; render de tmuxinator con ruby/ERB; `devcontainer read-configuration`;
  - dobles de prueba (un `docker` falso en el PATH) para scripts.
- Si una afirmación es riesgosa (una versión que no compila, un conflicto de apt), probala en un contenedor
  descartable antes de dejarla escrita.

**Desarrollo**
- `muav/dev:<distro>` tiene las herramientas; el workspace (src, build, install, log) vive en el HOST y se monta en `/ws`.
- NUNCA montes un workspace compilado en el host (p. ej. `~/ros2_px4_ws`, Jazzy nativo): sus rutas absolutas no
  existen en `/ws` y un `colcon build` dentro lo pisa. `images/dev/ws_guard.sh` lo detecta.

**Git**
- Conventional commits (`feat`, `fix`, `docs`, `refactor`, `chore`), en grupos lógicos. Sin atribución a IA ni
  `Co-Authored-By`.
- Rama de trabajo actual: `refactor/rename-packages`. Push al terminar cada paso del plan.

**Idioma**
- Documentación, comentarios y mensajes de scripts en español. Commits en inglés.

## Comandos

```bash
images/build.sh <distro> [base msgs bridge dev]      # imágenes x86 / multi-arch (+ devcontainer al construir dev)
./container_run.sh dev <distro> [restart]            # desarrollo: ws/<distro> → /ws
./container_run.sh bridge <distro>                   # bridge del GCS (noetic: MUAV_HOSTS=<drones>)
vcs import ws/humble/src < images/dev/humble.repos   # código de partida (PSDK)
vcs import ws/jazzy/src  < devices/px4_ros2/jazzy.repos
/opt/muav/ws_rosdep.sh                               # dentro de dev: dependencias de /ws/src
devices/<x>/container_build.sh                       # EN el dron (Jetson, Pi, companion)
tmuxinator start -p devices/<x>/tmuxinator.yml -h    # parámetros de cada dron (M300: devices/m300/{psdk,osdk}/)
```

## Trampas que más muerden

Lista completa y con evidencia en el plan (› Trampas conocidas). Las que rompen sin dar error:

- **Noetic es EOL**: `rosdep update` sin `--include-eol-distros` borra Noetic del caché.
- **Humble + Gazebo Harmonic**: `rosdep install -y` sobre algo que pida `ros_gz_*` DESINSTALA Harmonic (instala
  Fortress, que tiene `Conflicts`). Usá `ws_rosdep.sh` o `--skip-keys`.
- **Micro-XRCE-DDS Agent en Humble**: no compila con colcon (pide fastcdr 2): superbuild de cmake.
- **`px4_msgs` `main` no es una versión**: cambia la estructura de los mensajes sin aviso.
- **Fast-DDS entre contenedores del mismo host**: sin `--ipc host` se descubren pero no reciben datos.
- **devcontainer.json no anida variables** (`${localEnv:X:${localWorkspaceFolder}}` sale roto): defaults literales.
- **ROS 1**: dos nodos con el mismo nombre se echan entre sí (`__name:=` único).

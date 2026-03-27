# Docker — multiuav_gcs_bringup

Dos perfiles según el caso de uso:

| Perfil | Imagen | Dockerfile | Uso |
|--------|--------|------------|-----|
| `gcs` | `muavgcs:ros1-gcs` | `Dockerfile.gcs` | Desarrollo GCS diario (~4 GB) |
| `sim` | `muavgcs:ros1-sim` | `Dockerfile.sim` | Simulación PX4 + Gazebo (~9 GB) |

---

## Primera vez

### 1. Buildear la imagen

```bash
# Perfil GCS (recomendado para desarrollo)
docker build -t muavgcs:ros1-gcs -f Dockerfile.gcs .

# Perfil sim (hereda de gcs — buildear gcs primero)
docker build -t muavgcs:ros1-sim -f Dockerfile.sim .
```

### 2. Crear el contenedor y poblar el volumen

```bash
# Crea el contenedor (volumen en ~/work/ros_docker_volume)
./container_run.sh gcs

# Dentro del contenedor — solo la primera vez
bash /app/initDev.sh
```

Para sim, ejecutar `initDev.gcs.sh` primero y luego `initDev.sim.sh`:

```bash
./container_run.sh sim
# dentro del contenedor:
bash /app/initDev.gcs.sh
bash /app/initDev.sim.sh
```

---

## Uso diario

```bash
# Arrancar contenedor GCS (reanuda si ya existe)
./container_run.sh gcs

# Arrancar contenedor sim
./container_run.sh sim

# Reiniciar
./container_run.sh restart
```

---

## Estructura del volumen (`~/work/ros_docker_volume` → `/app`)

```
/app
├── Onboard-SDK/          ← compilado con cmake install
├── PX4-Autopilot/        ← solo en sim, compilado con make px4_sitl_default
└── catkin_ws/
    ├── build/
    ├── devel/
    └── src/
        ├── multiUAV_system/   (--branch GimbalPitch)
        ├── grvc-utils/        (--branch noetic)
        ├── ros_rtsp/
        ├── simple_vs/
        └── Onboard-SDK-ROS/
```

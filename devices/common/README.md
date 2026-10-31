# devices/common — lo compartido por los dispositivos

Origen: `multiuav_bringup/devices/init` (arranque del dron) y lo que antes estaba duplicado entre dispositivos.

| Ruta | Dónde corre | Para qué |
|---|---|---|
| `osdk/install_osdk.sh` | build de M300 OSDK, M210, `dev:noetic` | Instala el Onboard-SDK fijado |
| `osdk/entrypoint_osdk.sh` | contenedor OSDK | Inyecta las credenciales DJI (`cfg/UserConfig_osdk.txt`) en `dji_vehicle_node.launch` |
| `multimaster_watch.sh` | contenedor ROS 1 del dron | Multimaster con watchdog: espera al GCS y relanza si no lo descubre |
| `boot/` | **host** del dron (systemd) | Hora del dron desde el GCS al arrancar |

## Multimaster con watchdog

Los tmuxinator de los dispositivos ROS 1 lanzan `/opt/muav/multimaster_watch.sh`, no `multimaster.launch` a secas.
Es el comportamiento del viejo `init/ros/multimaster.sh`: el descubrimiento a veces no engancha al GCS a la primera.

1. Espera a que el roscore del GCS responda (`<primer host de MUAV_HOSTS>:11311`).
2. Lanza `/opt/muav/multimaster.launch` (el mismo archivo que usa `bridge:noetic`).
3. Si a los 20 s el GCS no aparece en `/master_discovery/list_masters`, lo mata y lo relanza.

## Arranque: hora desde el GCS

Las placas sin reloj con batería (Raspberry Pi, Jetson) arrancan con la fecha mal. `muav-timesync.service` le pide
la hora al GCS (`GET http://$GCS_HOST:4000/api/server/datetime`) y la aplica. Reemplaza al esquema viejo
`/etc/rc.local` → `/home/ubuntu/init/init.sh` → `synchdate.sh`, con el GCS como parámetro en vez de escrito en el
script.

```bash
sudo devices/common/boot/install.sh      # una vez, en el dron
sudo nano /etc/muav/boot.env             # GCS_HOST
journalctl -u muav-timesync               # ver qué pasó
```

## VPN (opcional)

Antes: `openvpn --config <x>.ovpn --auth-user-pass login.text &`, comentado en `init.sh`. Ahora con el servicio
estándar de Ubuntu (paquete `openvpn`), sin scripts propios:

```bash
sudo cp <red>.ovpn /etc/openvpn/client/<red>.conf
# usuario (línea 1) y contraseña (línea 2). NUNCA en este repo.
sudo install -m 600 /dev/stdin /etc/openvpn/client/<red>.login   # pegar las dos líneas, Ctrl-D
# en /etc/openvpn/client/<red>.conf:  auth-user-pass /etc/openvpn/client/<red>.login
sudo systemctl enable --now openvpn-client@<red>
```

## No se migró

- `init/ros/DJI_supervisor.js` y `init/ros/config.yaml`: esqueleto roto (`'child_proces'`, variable sin declarar).
- `M300/ros/` (supervisor Node con pm2 + `ros_*.sh` con rutas `/home/nvidia/...`): arrancaba todo nativo. Lo
  reemplazan los contenedores y los tmuxinator de cada dispositivo.

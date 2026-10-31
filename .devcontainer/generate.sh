#!/bin/bash
# Genera .devcontainer/<distro>/devcontainer.json (gitignored) desde devcontainer.template.json. Lo llama
# images/build.sh al construir dev; a mano si cambia la GPU o la plantilla:
#   .devcontainer/generate.sh <distro>
# Como createContainer.sh de px4_ros2_docker (detecta la GPU NVIDIA y activa esa configuración), pero sin pisar un
# archivo versionado y con una sola plantilla: VS Code ofrece solo las distros generadas.
#
# La ruta por defecto del workspace va LITERAL (devcontainer.json no anida ${...}): ws/<distro> de este repo, igual
# que ./container_run.sh dev. MUAV_WS_<DISTRO> la reemplaza en los dos.
# Los flags de GPU son los de container_run.sh: cambiarlos en los dos.
set -e

DISTRO=${1:?Uso: $0 <distro>}
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
OUT="$HERE/$DISTRO/devcontainer.json"

GPU=false
if command -v nvidia-smi > /dev/null 2>&1 && nvidia-smi > /dev/null 2>&1; then
    GPU=true
fi

mkdir -p "$HERE/$DISTRO"
python3 -I - "$HERE/devcontainer.template.json" "$OUT" "$DISTRO" "$ROOT/ws/$DISTRO" "$GPU" <<'PY'
import json, sys
template, out, distro, default_ws, gpu = sys.argv[1:]
text = open(template).read()
for key, value in (("__DISTRO_UPPER__", distro.upper()), ("__DISTRO__", distro), ("__DEFAULT_WS__", default_ws)):
    text = text.replace(key, value)
cfg = json.loads(text)
if gpu == "true":
    cfg["name"] += " (NVIDIA)"
    cfg["runArgs"] += ["--gpus=all", "--device=/dev/dri:/dev/dri"]
    cfg["containerEnv"].update({
        "NVIDIA_VISIBLE_DEVICES": "all",
        "NVIDIA_DRIVER_CAPABILITIES": "all",
        "__NV_PRIME_RENDER_OFFLOAD": "1",          # laptops híbridas: renderiza en la NVIDIA
        "__GLX_VENDOR_LIBRARY_NAME": "nvidia",
    })
with open(out, "w") as f:
    json.dump(cfg, f, indent=4, ensure_ascii=False)
    f.write("\n")
PY

echo "[devcontainer] $OUT  (GPU NVIDIA: $GPU)"

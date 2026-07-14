#!/bin/bash
# set_usb_mode.sh — Swapea el modo de gadget USB de la Jetson entre OSDK y PSDK.
#
# CONTEXTO:
#   El controlador USB del Tegra solo puede operar en un modo de gadget a la vez.
#   - OSDK usa CDC-ACM → expone /dev/ttyACM0 al host
#   - PSDK usa USB bulk → expone /dev/usb-ffs/bulk1 y bulk2
#   Ambos modos son mutuamente excluyentes.
#
# ARCHIVOS:
#   /opt/nvidia/l4t-usb-device-mode/nv-l4t-usb-device-mode-start.sh         ← activo (leído en cada boot)
#   /opt/nvidia/l4t-usb-device-mode/nv-l4t-usb-device-mode-start-osdk.sh    ← backup del original de L4T
#   /opt/nvidia/l4t-usb-device-mode/nv-l4t-usb-device-mode-start-psdk.sh    ← script de DJI PSDK
#
# USO:
#   sudo ./set_usb_mode.sh [osdk|psdk] [--now]
#
#   --now  Aplica el modo en caliente sin reboot (via systemctl restart).
#          Si el servicio L4T no existe, cae en reboot interactivo igual que antes.
#
# PREREQUISITOS (primera vez):
#   1. Guardar el script original de L4T:
#      sudo cp /opt/nvidia/l4t-usb-device-mode/nv-l4t-usb-device-mode-start.sh \
#              /opt/nvidia/l4t-usb-device-mode/nv-l4t-usb-device-mode-start-osdk.sh
#   2. Copiar el script de DJI (del paquete PSDK, dentro del zip de bulk config):
#      sudo cp startup_bulk/psdk-usb-configure.sh \
#              /opt/nvidia/l4t-usb-device-mode/nv-l4t-usb-device-mode-start-psdk.sh
#   Tras el primer swap, este script gestiona todo.

set -euo pipefail

SCRIPT_OSDK="/opt/nvidia/l4t-usb-device-mode/nv-l4t-usb-device-mode-start-osdk.sh"
SCRIPT_PSDK="/opt/nvidia/l4t-usb-device-mode/nv-l4t-usb-device-mode-start-psdk.sh"
SCRIPT_ACTIVE="/opt/nvidia/l4t-usb-device-mode/nv-l4t-usb-device-mode-start.sh"
MODE_FILE="/opt/nvidia/.usb_mode"
L4T_SERVICE="nv-l4t-usb-device-mode.service"

# ── helpers ──────────────────────────────────────────────────────────────────

die() { echo "[set_usb_mode] ERROR: $*" >&2; exit 1; }

check_root() {
    [ "$(id -u)" -eq 0 ] || die "Ejecutá con sudo: sudo $0 [osdk|psdk] [--now]"
}

check_prerequisites() {
    [ -f "$SCRIPT_OSDK" ] || die "Falta el backup del script OSDK en $SCRIPT_OSDK
  Primera vez? Ejecutá:
    sudo cp $SCRIPT_ACTIVE $SCRIPT_OSDK"
    [ -f "$SCRIPT_PSDK" ] || die "Falta el script PSDK en $SCRIPT_PSDK
  Primera vez? Ejecutá:
    sudo cp startup_bulk/psdk-usb-configure.sh $SCRIPT_PSDK"
}

current_mode() {
    [ -f "$MODE_FILE" ] && cat "$MODE_FILE" || echo "unknown"
}

reset_usb_gadget() {
    # Deshabilitar el gadget antes de reconfigurar para evitar el error
    # "device busy" que causa que el servicio L4T falle al reiniciar.
    local GADGET_DIR="/sys/kernel/config/usb_gadget"
    if [ -d "$GADGET_DIR" ]; then
        for gadget in "$GADGET_DIR"/*/; do
            local udc_file="$gadget/UDC"
            if [ -f "$udc_file" ] && [ -n "$(cat "$udc_file" 2>/dev/null)" ]; then
                echo "" > "$udc_file" 2>/dev/null || true
                echo "[set_usb_mode] Gadget $(basename "$gadget") desvinculado del UDC."
            fi
        done
    fi
}

apply_now() {
    echo "[set_usb_mode] Aplicando en caliente..."

    # Detener el servicio L4T y matar startup_bulk si estaba corriendo (modo PSDK previo)
    if systemctl is-active --quiet "$L4T_SERVICE" 2>/dev/null; then
        systemctl stop "$L4T_SERVICE" || true
    fi
    pkill -x startup_bulk 2>/dev/null || true

    # Desmontar los endpoints bulk si estaban montados (transición PSDK → OSDK)
    umount /dev/usb-ffs/bulk1 2>/dev/null || true
    umount /dev/usb-ffs/bulk2 2>/dev/null || true

    # Desvincular gadget USB del UDC antes de reconfigurar (evita "device busy")
    reset_usb_gadget
    sleep 1

    if systemctl list-unit-files "$L4T_SERVICE" &>/dev/null; then
        if ! systemctl restart "$L4T_SERVICE"; then
            echo "[set_usb_mode] WARN: El servicio falló. Ejecutando script directamente..."
            bash "$SCRIPT_ACTIVE" || true
        else
            echo "[set_usb_mode] Servicio $L4T_SERVICE reiniciado."
        fi
    else
        # Fallback: ejecutar el script directamente en background
        bash "$SCRIPT_ACTIVE" &
        echo "[set_usb_mode] Script ejecutado directamente (servicio systemd no encontrado)."
    fi

    # Para PSDK: montar los ffs endpoints y luego iniciar startup_bulk
    if [ "$(current_mode)" = "psdk" ]; then
        sleep 2

        # Crear y montar los directorios ffs si no están montados
        for EP in bulk1 bulk2; do
            mkdir -p "/dev/usb-ffs/$EP"
            if ! mountpoint -q "/dev/usb-ffs/$EP" 2>/dev/null; then
                mount -t functionfs "$EP" "/dev/usb-ffs/$EP" 2>/dev/null || true
            fi
        done

        sleep 1
        STARTUP_BULK=$(find /home -name "startup_bulk" -type f 2>/dev/null | head -1)
        if [ -n "$STARTUP_BULK" ]; then
            "$STARTUP_BULK" /dev/usb-ffs/bulk1 &
            "$STARTUP_BULK" /dev/usb-ffs/bulk2 &
            echo "[set_usb_mode] startup_bulk iniciado para bulk1 y bulk2."
        else
            echo "[set_usb_mode] WARN: startup_bulk no encontrado. Inicialo manualmente."
            echo "  Ruta esperada: ~/Desktop/startup_bulk/startup_bulk"
        fi
    fi
}

check_status() {
    echo ""
    echo "══ Estado USB mode ══════════════════════════════════════"
    echo "  Modo guardado   : $(current_mode)"

    if cmp -s "$SCRIPT_ACTIVE" "$SCRIPT_OSDK" 2>/dev/null; then
        echo "  Script activo   : OSDK"
    elif cmp -s "$SCRIPT_ACTIVE" "$SCRIPT_PSDK" 2>/dev/null; then
        echo "  Script activo   : PSDK"
    else
        echo "  Script activo   : DESCONOCIDO (modificado manualmente?)"
    fi

    echo ""
    echo "  Servicio $L4T_SERVICE:"
    systemctl is-active "$L4T_SERVICE" 2>/dev/null && \
        echo "    activo" || echo "    inactivo"

    echo ""
    echo "  Procesos startup_bulk:"
    if pgrep -x startup_bulk > /dev/null 2>&1; then
        pgrep -xa startup_bulk | sed 's/^/    /'
    else
        echo "    ninguno corriendo"
    fi

    echo ""
    echo "  Endpoints USB bulk:"
    for EP in bulk1 bulk2; do
        if mountpoint -q "/dev/usb-ffs/$EP" 2>/dev/null; then
            echo "    /dev/usb-ffs/$EP → montado"
        else
            echo "    /dev/usb-ffs/$EP → NO montado"
        fi
    done
    echo "══════════════════════════════════════════════════════════"
    echo ""
}

# ── main ─────────────────────────────────────────────────────────────────────

check_root
check_prerequisites

TARGET_MODE="${1:-}"
APPLY_NOW=0
[ "${2:-}" = "--now" ] && APPLY_NOW=1

if [ -z "$TARGET_MODE" ] || [ "$TARGET_MODE" = "status" ]; then
    check_status
    echo "Uso: sudo $0 [osdk|psdk] [--now]"
    exit 0
fi

case "$TARGET_MODE" in
    osdk|psdk) ;;
    *) die "Modo inválido '$TARGET_MODE'. Usá: osdk | psdk" ;;
esac

CURRENT=$(current_mode)

if [ "$CURRENT" = "$TARGET_MODE" ]; then
    echo "[set_usb_mode] El modo ya es '$TARGET_MODE'."
    if [ "$APPLY_NOW" -eq 1 ]; then
        echo "[set_usb_mode] Forzando re-aplicación..."
        apply_now
        echo "[set_usb_mode] Listo."
        check_status
    else
        echo "  Para re-aplicar sin reboot: sudo $0 $TARGET_MODE --now"
    fi
    exit 0
fi

# Swap del script activo
if [ "$TARGET_MODE" = "osdk" ]; then
    cp "$SCRIPT_OSDK" "$SCRIPT_ACTIVE"
    echo "[set_usb_mode] Script activo → OSDK (CDC-ACM → /dev/ttyACM0)"
else
    cp "$SCRIPT_PSDK" "$SCRIPT_ACTIVE"
    echo "[set_usb_mode] Script activo → PSDK (USB bulk → /dev/usb-ffs/bulk1,bulk2)"
fi

echo "$TARGET_MODE" > "$MODE_FILE"
echo "[set_usb_mode] Modo seteado a '$TARGET_MODE'."

if [ "$APPLY_NOW" -eq 1 ]; then
    apply_now
    echo "[set_usb_mode] Listo. Modo '$TARGET_MODE' activo."
    check_status
else
    echo ""
    echo "  El cambio toma efecto en el próximo arranque."
    echo "  Para aplicar ahora sin reboot: sudo $0 $TARGET_MODE --now"
    echo ""
    read -r -p "  ¿Reiniciar ahora? [s/N] " CONFIRM
    if [[ "$CONFIRM" =~ ^[sS]$ ]]; then
        echo "[set_usb_mode] Reiniciando..."
        reboot
    else
        echo "[set_usb_mode] Reboot pendiente. El modo '$TARGET_MODE' se activará en el próximo boot."
    fi
fi
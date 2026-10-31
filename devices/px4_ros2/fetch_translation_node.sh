#!/bin/bash
# Trae translation_node y px4_msgs_old del PX4 del contrato (px4.env) a <ws>/src, SIN clonar PX4 entero: un commit,
# sin historia, solo esas dos carpetas.
#   fetch_translation_node.sh <ws_src>
#
# NO usa Tools/copy_to_ros_ws.sh de PX4: ese pisa los .msg de px4_msgs con los del firmware. Aquí px4_msgs es el del
# contrato, que para este commit es idéntico (decisión 19).
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC=${1:?Uso: $0 <ws_src>}
# shellcheck source=px4.env
source "$HERE/px4.env"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

git -C "$TMP" init -q
git -C "$TMP" remote add origin "$PX4_REPO"
git -C "$TMP" sparse-checkout set msg/translation_node msg/px4_msgs_old
git -C "$TMP" fetch -q --depth 1 --filter=blob:none origin "$PX4_COMMIT"
git -C "$TMP" checkout -q FETCH_HEAD

mkdir -p "$SRC"
cp -a "$TMP/msg/translation_node" "$TMP/msg/px4_msgs_old" "$SRC/"
echo "[translation_node] PX4 $PX4_COMMIT → $SRC/{translation_node,px4_msgs_old}"

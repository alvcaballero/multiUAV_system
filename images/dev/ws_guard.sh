# Se hace `source` (container_run.sh, .devcontainer/initialize.sh). Corre en el HOST.
# Un workspace compilado FUERA del contenedor (p. ej. ~/ros2_px4_ws, Jazzy nativo) guarda rutas absolutas del host en
# install/ y build/: montado en /ws queda roto, y un colcon build dentro pisa el del host.
#
# muav_ws_built_elsewhere <dir>: imprime dónde se compiló si NO fue en /ws; nada si está bien o sin compilar.
#   colcon: install/setup.sh  → _colcon_prefix_chain_sh_COLCON_CURRENT_PREFIX=<prefijo>   (debe ser /ws/install)
#   catkin: build/CMakeCache.txt → CMAKE_HOME_DIRECTORY:INTERNAL=<src>                  (debe ser /ws/src)
muav_ws_built_elsewhere() {
    local ws=$1 p
    if [ -f "$ws/install/setup.sh" ]; then
        p=$(grep -m1 '^_colcon_prefix_chain_sh_COLCON_CURRENT_PREFIX=' "$ws/install/setup.sh" | cut -d= -f2)
        if [ -n "$p" ] && [ "$p" != /ws/install ]; then echo "$p"; return 0; fi
    fi
    if [ -f "$ws/build/CMakeCache.txt" ]; then
        p=$(grep -m1 '^CMAKE_HOME_DIRECTORY:INTERNAL=' "$ws/build/CMakeCache.txt" | cut -d= -f2)
        if [ -n "$p" ] && [ "$p" != /ws/src ]; then echo "$p"; return 0; fi
    fi
    return 0
}

#!/bin/bash
# Instala el DJI Onboard-SDK (librería CMake, NO catkin) en /usr/local. Lo necesita dji_osdk_ros COMPLETO.
# Lo usan los Dockerfile de los dispositivos OSDK (M300, M210, ...):
#   COPY devices/common/osdk/install_osdk.sh /tmp/ && RUN /tmp/install_osdk.sh <commit>
# Queda en /root/Onboard-SDK: los alias del MatriceSeries_ConfigTool usan utility/bin/<arch>/.
set -euo pipefail

VERSION=${1:?Uso: $0 <commit de dji-sdk/Onboard-SDK>}

git clone https://github.com/dji-sdk/Onboard-SDK.git /root/Onboard-SDK
cd /root/Onboard-SDK
git checkout "$VERSION"

# Includes que faltan con gcc >= 11 (Jammy). En compiladores anteriores no cambian nada.
sed -i '1i #include <string>\n#include <cstdio>' osdk-core/modules/inc/filemgr/impl/mmap_file_buffer.hpp
sed -i '1i #include <cstdio>' osdk-core/modules/src/filemgr/impl/mmap_file_buffer.cpp

mkdir build && cd build
cmake ..
make -j"$(nproc)"
make install

#!/bin/bash

# Copyright (c) 2013 Claudiu-Vlad Ursache <claudiu@cvursache.com>
#
# Based on work by Mike Tigas:
# 
# Copyright (c) 2012 Mike Tigas <mike@tig.as>

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

set -u

ARCHS=("armv7" "i386" "armv7s")
SDKS=("iphoneos" "macosx" "iphoneos")
LIB_NAME="tor-0.2.3.25"

CURRENT_DIR=$(pwd)

TEMP_DIR="${CURRENT_DIR}/tmp"
TEMP_LIB_PATH="${CURRENT_DIR}/tmp/${LIB_NAME}"

DEPENDENCIES_DIR="${CURRENT_DIR}/dependencies"
DEPENDENCIES_DIR_LIB="${DEPENDENCIES_DIR}/lib"
DEPENDENCIES_DIR_HEAD="${DEPENDENCIES_DIR}/include"

LIB_DEST_DIR="${CURRENT_DIR}/tor-dest-lib"
HEADER_DEST_DIR="${CURRENT_DIR}/tor-dest-include"

# Cleanups from previous build
rm -rf "${TEMP_LIB_PATH}*" "${LIB_NAME}"

# Copy dependencies that are only available for one platform, e.g. sim only
SDK_PATH_SIM=$(xcrun -sdk macosx --show-sdk-path)
mkdir -p "${DEPENDENCIES_DIR}/sys/"
cp -R "${SDK_PATH_SIM}/usr/include/sys/ptrace.h" "${DEPENDENCIES_DIR}/sys/"

# Apply patches to files that break the build
apply_patches()
{
   PATCHES_DIR=$1   
   ####
   # Patch to remove the "DisableDebuggerAttachment" ptrace() calls
   # that are not allowed in App Store apps
   patch -p3 < "${PATCHES_DIR}/patch-tor-nsenviron.diff"

   # Patch to remove "_NSGetEnviron()" call not allowed in App Store
   # apps (even fails to compile under iPhoneSDK due to that function
   # being undefined)
   patch -p3 < "${PATCHES_DIR}/patch-tor-nsenviron.diff"
}

# Make install puts only certain files to the directory specified by 
# --prefix on ./configure , that's why make install is skipped and the 
# required files are copied manually instead using copy_make_results
copy_make_results()
{
   BUILD_DIR=$1; TEMP_MAKE_DIR=$2;

   mkdir -p "${TEMP_MAKE_DIR}/lib"
   mkdir -p "${TEMP_MAKE_DIR}/include/common/"
   mkdir -p "${TEMP_MAKE_DIR}/include/or/"
   mkdir -p "${TEMP_MAKE_DIR}/include/tools/"

   # Copy the resulted library files
   cp "${BUILD_DIR}/src/common/libor-crypto.a" "${TEMP_MAKE_DIR}/lib/"
   cp "${BUILD_DIR}/src/common/libor-event.a" "${TEMP_MAKE_DIR}/lib/"
   cp "${BUILD_DIR}/src/common/libor.a" "${TEMP_MAKE_DIR}/lib/"
   cp "${BUILD_DIR}/src/or/libtor.a" "${TEMP_MAKE_DIR}/lib/"

   # Copy the header files
   cp "${BUILD_DIR}/orconfig.h" "${TEMP_MAKE_DIR}"

   find "${BUILD_DIR}/src/common" -name "*.h" -exec cp {} "${TEMP_MAKE_DIR}/include/common/" \;
   find "${BUILD_DIR}/src/or" -name "*.h" -exec cp {} "${TEMP_MAKE_DIR}/include/or/" \;
   find "${BUILD_DIR}/src/or" -name "*.i" -exec cp {} "${TEMP_MAKE_DIR}/include/or/" \;
   find "${BUILD_DIR}/src/tools" -name "*.h" -exec cp {} "${TEMP_MAKE_DIR}/include/tools/" \;
}

# Unarchive library, then configure and make for specified architectures
configure_make()
{
   ARCH=$1; GCC=$2; SDK_PATH=$3;
   
   TEMP_LIB_PATH_ARCH="${TEMP_LIB_PATH}-${ARCH}"

   LOG_FILE="${TEMP_LIB_PATH}-${ARCH}.log"
   tar xfz "${LIB_NAME}.tar.gz";
   
   TEMP_BUILD_DIR="${CURRENT_DIR}/${LIB_NAME}";

   pushd .;
   cd "${TEMP_BUILD_DIR}";

   apply_patches "${CURRENT_DIR}/build-patches"
   
   # libz.dylib will be copied over as libz.a to be used successfully by tor's configure
   cp "${SDK_PATH}/usr/lib/libz.dylib" "${DEPENDENCIES_DIR_LIB}/libz.a"
   cp "${SDK_PATH}/usr/include/zlib.h" "${DEPENDENCIES_DIR_HEAD}"

   #########################################
   # Configure and make

   if [ "${ARCH}" == "i386" ];
   then
      HOST_FLAG=""
   else
      HOST_FLAG="--host=arm-apple-darwin11 --target=arm-apple-darwin11 --disable-gcc-hardening --disable-linker-hardening"
   fi

   mkdir -p "${TEMP_LIB_PATH_ARCH}"

   ./configure --enable-static-openssl --enable-static-libevent --enable-static-zlib ${HOST_FLAG} \
   --prefix="${TEMP_LIB_PATH_ARCH}" \
   --with-openssl-dir="${DEPENDENCIES_DIR}" \
   --with-libevent-dir="${DEPENDENCIES_DIR}" \
   --with-zlib-dir="${DEPENDENCIES_DIR}" \
   --disable-asciidoc \
   CC="${GCC} -L${DEPENDENCIES_DIR}" \
   CFLAGS="-arch ${ARCH} -isysroot ${SDK_PATH} -I${DEPENDENCIES_DIR} -L${DEPENDENCIES_DIR}" \
   CPPLAGS="-arch ${ARCH} -isysroot ${SDK_PATH} -I${DEPENDENCIES_DIR} -L${DEPENDENCIES_DIR}" &> "${LOG_FILE}"

   make -j2 &> "${LOG_FILE}"; 

   copy_make_results "${TEMP_BUILD_DIR}" "${TEMP_LIB_PATH_ARCH}"

   popd; rm -rf "${LIB_NAME}";
}

for ((i=0; i < ${#ARCHS[@]}; i++))
do
   SDK_PATH=$(xcrun -sdk ${SDKS[i]} --show-sdk-path)
   GCC=$(xcrun -sdk ${SDKS[i]} -find gcc)
   configure_make "${ARCHS[i]}" "${GCC}" "${SDK_PATH}"
done

# Combine libraries for different architectures into one
# Use .a files from the temp directory by providing relative paths
mkdir -p "${LIB_DEST_DIR}"
create_lib()
{
   LIB_ARCH_SRC=$1; LIB_ARCH_DST=$2;
   
   # Append TEMP_LIB_PATH at the begining of every ARCHS array element
   LIB_PATHS=( "${ARCHS[@]/#/${TEMP_LIB_PATH}-}" )

   # Apend LIB_ARCH_SRC at the end of every LIB_PATHS array element
   LIB_PATHS=( "${LIB_PATHS[@]/%//${LIB_ARCH_SRC}}" )

   lipo ${LIB_PATHS[@]} -create -output "${LIB_ARCH_DST}"
}

create_lib "lib/libor-crypto.a" "${LIB_DEST_DIR}/libor-crypto.a"
create_lib "lib/libor-event.a" "${LIB_DEST_DIR}/libor-event.a"
create_lib "lib/libor.a" "${LIB_DEST_DIR}/libor.a"
create_lib "lib/libtor.a" "${LIB_DEST_DIR}/libtor.a"
 
# Copy header files + final cleanups
mkdir -p "${HEADER_DEST_DIR}"
cp -R "${TEMP_LIB_PATH}-${ARCHS[0]}/include" "${HEADER_DEST_DIR}"
rm -rf "${TEMP_DIR}"

#!/bin/bash
set -u
 
# Setup architectures, library name and other vars + cleanup from previous runs
ARCHS=("armv7s" "armv7" "i386")
SDKS=("iphoneos" "iphoneos" "macosx")
LIB_NAME="libevent-2.0.21-stable"
TEMP_LIB_PATH="/tmp/${LIB_NAME}"
DEPENDENCIES_DIR="/Users/claudiu-vladursache/temp-libevent/dependencies"
LIB_DEST_DIR="lib"
HEADER_DEST_DIR="include/libevent"
rm -rf "${HEADER_DEST_DIR}" "${LIB_DEST_DIR}" "${TEMP_LIB_PATH}*" "${LIB_NAME}"

# Unarchive library, then configure and make for specified architectures
configure_make()
{
   ARCH=$1; GCC=$2; SDK_PATH=$3;
   LOG_FILE="${TEMP_LIB_PATH}-${ARCH}.log"
   tar xfz "${LIB_NAME}.tar";
   pushd .; cd "${LIB_NAME}";

   mkdir -p "${TEMP_LIB_PATH}-${ARCH}"

   ./configure --disable-shared --enable-static --disable-debug-mode --host=arm-apple-darwin11 \
   --prefix="${TEMP_LIB_PATH}-${ARCH}" \
   CC="${GCC}" &> "${LOG_FILE}"

   make -j2 &> "${LOG_FILE}"; 
   make install &> "${LOG_FILE}";

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
create_lib()
{
   LIB_SRC=$1; LIB_DST=$2;
   LIB_PATHS=( "${ARCHS[@]/#/${TEMP_LIB_PATH}-}" )
   LIB_PATHS=( "${LIB_PATHS[@]/%//${LIB_SRC}}" )
   lipo ${LIB_PATHS[@]} -create -output "${LIB_DST}"
}
mkdir "${LIB_DEST_DIR}";
create_lib "lib/libevent.a" "${LIB_DEST_DIR}/libevent.a"
create_lib "lib/libevent_core.a" "${LIB_DEST_DIR}/libevent_core.a"
create_lib "lib/libevent_extra.a" "${LIB_DEST_DIR}/libevent_extra.a"
create_lib "lib/libevent_openssl.a" "${LIB_DEST_DIR}/libevent_openssl.a"
create_lib "lib/libevent_pthreads.a" "${LIB_DEST_DIR}/libevent_pthreads.a"
 
# Copy header files + final cleanups
cp -R "${TEMP_LIB_PATH}-${ARCHS[0]}/include" "${HEADER_DEST_DIR}"
rm -rf "${TEMP_LIB_PATH}-*" "{LIB_NAME}"

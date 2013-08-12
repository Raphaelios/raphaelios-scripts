#!/bin/bash
set -u
 
# Setup architectures, library name and other vars + cleanup from previous runs
ARCHS=("armv7s" "armv7" "i386")
SDKS=("iphoneos" "iphoneos" "macosx")
LIB_NAME="openssl-1.0.1e"
TEMP_LIB_PATH="/tmp/${LIB_NAME}"
LIB_DEST_DIR="lib"
HEADER_DEST_DIR="include"
rm -rf "${HEADER_DEST_DIR}" "${LIB_DEST_DIR}" "${TEMP_LIB_PATH}*" "${LIB_NAME}"
 
# Unarchive library, then configure and make for specified architectures
configure_make()
{
   ARCH=$1; GCC=$2; SDK_PATH=$3;
   LOG_FILE="${TEMP_LIB_PATH}-${ARCH}.log"
   tar xfz "${LIB_NAME}.tar.gz"
   pushd .; cd "${LIB_NAME}";

   ./Configure BSD-generic32 --openssldir="${TEMP_LIB_PATH}-${ARCH}" &> "${LOG_FILE}"
   perl -i -pe "s|^CC= gcc|CC= ${GCC} -arch ${ARCH}|g" Makefile
   perl -i -pe "s|^CFLAG= (.*)|CFLAG= -isysroot ${SDK_PATH} \$1|g" Makefile
   
   make &> "${LOG_FILE}"; make install &> "${LOG_FILE}";
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
create_lib "lib/libcrypto.a" "${LIB_DEST_DIR}/libcrypto.a"
create_lib "lib/libssl.a" "${LIB_DEST_DIR}/libssl.a"
 
# Copy header files + final cleanups
mkdir -p "${HEADER_DEST_DIR}"
cp -R "${TEMP_LIB_PATH}-${ARCHS[0]}/include" "${HEADER_DEST_DIR}"
rm -rf "${TEMP_LIB_PATH}-*" "{LIB_NAME}"

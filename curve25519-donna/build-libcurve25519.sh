#!/bin/sh
#  Automatic build script for curve25519-donna for iPhoneOS and iPhoneSimulator
# Created by Christine Corbett Moran 11/30/2013
#
#
###########################################################################
#  Change values here													  #
#																		  #
SDKVERSION="7.0"														  #
#																		  #
# Probably shouldn't need to change anything under here

CURRENTPATH=`pwd`
CFLAGS="-Wmissing-prototypes -Wdeclaration-after-statement -O2 -Wall"
ARCHS="i386 armv7 armv7s"
DEVELOPER=`xcode-select -print-path`

mkdir -p "${CURRENTPATH}/src"
mkdir -p "${CURRENTPATH}/lib"

cd "${CURRENTPATH}/src/"
git clone https://github.com/agl/curve25519-donna.git
cd "${CURRENTPATH}/src/curve25519-donna/"

for ARCH in ${ARCHS}
do
	make clean
	if [ "${ARCH}" == "i386" ];
	then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
	fi
	export DEVELOPER_PLATFORM="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export SDK="${PLATFORM}${SDKVERSION}.sdk"
	echo "Building curve25519-donna for ${PLATFORM} ${SDKVERSION} ${ARCH}"
	export CC="/Applications/Xcode.app/Contents/Developer/usr/bin/gcc -arch ${ARCH} -miphoneos-version-min=7.0 -isysroot ${DEVELOPER_PLATFORM}/SDKs/${SDK}  ${CFLAGS}"
	mkdir -p "${CURRENTPATH}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"
	LOG="${CURRENTPATH}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk/curve25519-donna.log"
	$CC -c curve25519-donna.c -m32  curve25519-donna.c >> "${LOG}" 2>&1
	ar -rc curve25519-donna.a curve25519-donna.o >> "${LOG}" 2>&1
	ranlib curve25519-donna.a >> "${LOG}" 2>&1
	mv curve25519-donna.a ${CURRENTPATH}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk/curve25519-donna.a
done

echo "Build library for ${ARCHS}..."
lipo -create ${CURRENTPATH}/bin/iPhoneSimulator${SDKVERSION}-i386.sdk/curve25519-donna.a ${CURRENTPATH}/bin/iPhoneOS${SDKVERSION}-armv7.sdk/curve25519-donna.a ${CURRENTPATH}/bin/iPhoneOS${SDKVERSION}-armv7s.sdk/curve25519-donna.a -output ${CURRENTPATH}/lib/curve25519-donna.a  


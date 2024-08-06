#!/bin/bash

# PREREQUISITES:
# - Install target `rustup target add aarch64-linux-android`
# - Install NDK from Android Studio

# Manual build script for Android

DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd ${DIR}
PROJECT_ROOT=`pwd`

# Get the git version
GITINFO="" #$(git describe --always --dirty | sed 's/-/_/')

APPNAME=test_dsp


if [ "$1" == "clean" ] ; then
    echo "Cleaning"
    rm -f freethedsp/demo/test_dsp
    exit 0
elif [ "$1" == "install" ] ; then
    PERFORM_INSTALL=1
    if [ "$2" == "debug" ] ; then
        BUILDTYPE="debug"
    else
        BUILDTYPE="release"
    fi
elif [ "$1" == "releaseme" ] ; then
    PLATFORM_CONFIGS_ROOT=$2
    if [ -z "$PLATFORM_CONFIGS_ROOT" ] ; then
        echo "Usage: $0 releaseme <platform_configs_root>"
        exit 1
    fi
elif [ "$1" == "run" ] ; then
    RUN_APP=1
elif [ "$1" == "build" ] ; then
    if [ "$2" == "debug" ] ; then
        BUILDTYPE="debug"
        CARGO_BUILD_FLAGS=""
    else
        BUILDTYPE="release"
        CARGO_BUILD_FLAGS="--release"
    fi
else
    echo "Usage: $0 [build|clean|install]"
    exit 1
fi


echo ""
echo "=> Configuring Android build settings <============================================="
echo ""

# Android SDK and NDK paths
if [ -z "$ANDROID_HOME" ]; then
    export ANDROID_HOME=$HOME/Android/Sdk
fi
echo "Using ANDROID_HOME: ${ANDROID_HOME}"
# If ANDROID_NDK_HOME is not set, then use the latest NDK in the SDK
if [ -z "$ANDROID_NDK_HOME" ]; then
    TMP_NDK_VER=$(ls $ANDROID_HOME/ndk | tail -n1)
    if [ -z "$TMP_NDK_VER" ] ; then
        echo "Could not find NDK in Android SDK"
        echo "  Is the Android SDK and NDK installed?"
        exit 1
    fi
    export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/$TMP_NDK_VER
fi
echo "Using ANDROID_NDK_HOME: ${ANDROID_NDK_HOME}"
if [ -z "$ANDROID_TOOLCHAIN_PATH" ]; then
    ANDROID_TOOLCHAIN_PATH=${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake
fi
echo "Using ANDROID_TOOLCHAIN_PATH: ${ANDROID_TOOLCHAIN_PATH}"
if [ -z "$ANDROID_NDK_TOOLCHAIN_BIN_PATH" ]; then
    ANDROID_NDK_TOOLCHAIN_BIN_PATH=${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin
fi
echo "Using ANDROID_NDK_TOOLCHAIN_BIN_PATH: ${ANDROID_NDK_TOOLCHAIN_BIN_PATH}"
if [ -z "$ANDROID_NDK_VARIANT" ]; then
    ANDROID_NDK_VARIANT=34
fi
echo "Using ANDROID_NDK_VARIANT: ${ANDROID_NDK_VARIANT}"
if [ -z "$ANDROID_PLATFORM" ]; then
    ANDROID_PLATFORM=android-${ANDROID_NDK_VARIANT}
fi
echo "Using ANDROID_PLATFORM: ${ANDROID_PLATFORM}"
if [ -z "$ANDROID_SDK_BUILD_TOOLS_REVISION" ]; then
    ANDROID_SDK_BUILD_TOOLS_REVISION=35.0.0
fi
echo "Using ANDROID_SDK_BUILD_TOOLS_REVISION: ${ANDROID_SDK_BUILD_TOOLS_REVISION}"
if [ -z "$ANDROID_TARGET_ARCH" ]; then
    ANDROID_TARGET_ARCH=arm64-v8a
fi
echo "Using ANDROID_TARGET_ARCH: ${ANDROID_TARGET_ARCH}"
if [ -z "$ANDROID_SYSROOT_BASE" ]; then
  ANDROID_SYSROOT_BASE=${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot
fi
echo "Using ANDROID_SYSROOT_BASE: ${ANDROID_SYSROOT_BASE}"
if [ -z "$ANDROID_TOOLCHAIN_CLASS" ]; then
  ANDROID_TOOLCHAIN_CLASS=aarch64-linux-android
fi
if [ -z "$ANDROID_SYSROOT" ]; then
  ANDROID_SYSROOT=${ANDROID_SYSROOT_BASE}/usr/lib/${ANDROID_TOOLCHAIN_CLASS}/${ANDROID_NDK_VARIANT}
fi
echo "Using ANDROID_SYSROOT: ${ANDROID_SYSROOT}"

# Set up a hack for -lgcc failing
# unwind.a is supposed to be the replacement for gcc stuff in android IIRC
# so we just make a fake libgcc.a that links to unwind.a
ANDROIDLIBLOC=$(find $ANDROID_HOME | grep unwind\\.a | grep aarch64 | grep -v musl)
if [ -z "$ANDROIDLIBLOC" ] ; then
    echo "Could not find unwind.a in Android SDK"
    echo "  Is the Android SDK and NDK installed?"
    exit 1
fi
ANDROIDLIB_DIR=$(dirname $ANDROIDLIBLOC)
ANDROIDLIBGCC_PATH=$ANDROIDLIB_DIR/libgcc.a
echo "INPUT(-lunwind)" > $ANDROIDLIBGCC_PATH


cd freethedsp/demo

if [ ! -z "$RUN_APP" ] ; then
    echo "Running ${APPNAME}"
    adb shell su -c rm /data/local/tmp/${APPNAME}
    exit 0
fi

# Directly install to device for debug
if [ ! -z "$PERFORM_INSTALL" ] ; then
    echo "Installing ${APPNAME} to android device"

    adb shell su -c rm -f /data/local/tmp/${APPNAME}
    adb shell su -c rm -f /data/local/tmp/freethedsp.so
    adb shell su -c rm -rf /data/local/tmp/out
    adb push ${APPNAME} /data/local/tmp/
    adb push freethedsp.so /data/local/tmp/
    adb push out /data/local/tmp/
    adb shell su -c chmod +x /data/local/tmp/${APPNAME}
    echo "${APPNAME} installed to /data/local/tmp/${APPNAME}"
    echo ""
    exit 0
fi

# After build push to the platform_configs repo for release
if [ ! -z "${PLATFORM_CONFIGS_ROOT}" ] ; then
    PLATFORM_CONFIGS_S3_BINARIES_YAML="${PLATFORM_CONFIGS_ROOT}/scripts/files/s3_binaries.yaml"
    PLATFORM_CONFIGS_BINARIES="${PLATFORM_CONFIGS_ROOT}/binaries"
    if [ ! -d "${PLATFORM_CONFIGS_ROOT}" ] ; then
        echo "PLATFORM_CONFIGS_ROOT ${PLATFORM_CONFIGS_ROOT} does not exist"
        exit 1
    fi
    if [ ! -f "${PLATFORM_CONFIGS_S3_BINARIES_YAML}" ] ; then
        echo "PLATFORM_CONFIGS_S3_BINARIES_YAML ${PLATFORM_CONFIGS_S3_BINARIES_YAML} does not exist"
        exit 1
    fi
    if [ ! -d "${PLATFORM_CONFIGS_BINARIES}" ] ; then
        echo "PLATFORM_CONFIGS_BINARIES ${PLATFORM_CONFIGS_BINARIES} does not exist"
        exit 1
    fi
    LATEST_BIN_PATH=$(ls output/*.bin | grep ${GITINFO} | sort | tail -n 1) || true
    LATEST_BIN=$(basename ${LATEST_BIN_PATH})
    if [ -z "$LATEST_BIN" ] ; then
        echo "Could not find latest binary"
        exit 1
    fi

    # copy the binary to the platform_configs repo
    cmd="cp output/${LATEST_BIN} ${PLATFORM_CONFIGS_BINARIES}"
    echo "Running: ${cmd}"
    ${cmd}

    # record the binary in the s3_binaries.yaml file
    echo "Recording ${LATEST_BIN} to ${PLATFORM_CONFIGS_S3_BINARIES_YAML}"
    echo "  -" >> ${PLATFORM_CONFIGS_S3_BINARIES_YAML}
    echo "    key: ${LATEST_BIN}" >> ${PLATFORM_CONFIGS_S3_BINARIES_YAML} 
    echo "    path: binaries/${LATEST_BIN}" >> ${PLATFORM_CONFIGS_S3_BINARIES_YAML}
    echo "    sha256: $(sha256sum output/${LATEST_BIN} | awk '{print $1}')" >> ${PLATFORM_CONFIGS_S3_BINARIES_YAML}

    exit 0
fi


echo ""
echo "=> Building ${ANDROID_TOOLCHAIN_CLASS} in ${BUILDTYPE} <========================="
echo ""


export PATH=$PATH:$ANDROID_NDK_TOOLCHAIN_BIN_PATH

export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER=${ANDROID_TOOLCHAIN_CLASS}${ANDROID_NDK_VARIANT}-clang++
export CC_aarch64_linux_android=${ANDROID_TOOLCHAIN_CLASS}${ANDROID_NDK_VARIANT}-clang
export CXX_aarch64_linux_android=${ANDROID_TOOLCHAIN_CLASS}${ANDROID_NDK_VARIANT}-clang++
export AR=${ANDROID_NDK_TOOLCHAIN_BIN_PATH}/llvm-ar

# These are embedded into build.rs in tflite.rs
export ANDROID_CLANG_ARGS1="--sysroot=${ANDROID_SYSROOT}"
export ANDROID_CLANG_ARGS2="-I${ANDROID_NDK_HOME}/sources/cxx-stl/llvm-libc++/include/"
export ANDROID_CLANG_ARGS3="-I${ANDROID_SYSROOT_BASE}/usr/include/${ANDROID_TOOLCHAIN_CLASS}/"
export ANDROID_CLANG_ARGS4="-I${ANDROID_SYSROOT_BASE}/usr/include/"

export CROSS_CLANG="${CC_aarch64_linux_android}"
export CROSS_CLANGPP="${CXX_aarch64_linux_android}"


cmd="${CROSS_CLANG} -Iout -Llibs/openq865 -Iinclude run.c out/calculator_stub.c -I../include -o test_dsp -ladsprpc -ldl"
#cmd="${CROSS_CLANG} -Iout -Llibs/oneplus3 -Iinclude run.c out/calculator_stub.c ../freethedsp.c -I../include -o test_dsp -ladsprpc -ldl"
#cmd="${CROSS_CLANG} -shared -Iout -Iinclude run.c"
echo "Running: ${cmd}"
${cmd}
echo "exit code: $?"
# cmd="${CROSS_CLANG} -I../include -shared ../freethedsp.c -o freethedsp.so"
# echo "Running: ${cmd}"
# ${cmd}
# echo "exit code: $?"

#gcc -L/system/vendor/lib64 -Iout -Iinclude run.c out/calculator_stub.c ../freethedsp.c -I../include -o test_dsp -ladsprpc -ldl
exit $?
# Get the current time as seconds since epoch
DATE=$(date +%s)

mkdir -p output
if [ "${BUILDTYPE}" == "debug" ]; then NAME_SUFFIX="-debug"; fi

BINNAME="${APPNAME}-${DATE}-${GITINFO}${NAME_SUFFIX}.bin"

cmd="cp target/${ANDROID_TOOLCHAIN_CLASS}/${BUILDTYPE}/${APPNAME} output/${BINNAME}"
echo ""
echo "Running: ${cmd}"
${cmd}
echo ""
echo "=> Copied binary to output/${BINNAME} <========================="
echo ""

/vendor/lib64/libadsprpc.so
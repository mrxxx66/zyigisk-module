#!/bin/bash
# Local build script for HyperOS SF Bypass module

echo "=== HyperOS SF Bypass Local Build Script ==="
echo ""

# Check if ANDROID_NDK_ROOT is set
if [ -z "$ANDROID_NDK_ROOT" ]; then
    echo "Error: ANDROID_NDK_ROOT environment variable is not set."
    echo "Please set it to your Android NDK path."
    exit 1
fi

echo "Android NDK: $ANDROID_NDK_ROOT"

# Clone Dobby if not exists
if [ ! -d "jni/external/dobby" ]; then
    echo "Cloning Dobby library..."
    git clone https://github.com/jmpews/Dobby.git jni/external/dobby
    cd jni/external/dobby
    git checkout v2023.11.23
    cd ../../..
else
    echo "Dobby library already cloned."
fi

# Build Dobby
if [ ! -f "jni/external/dobby/build/libdobby.a" ]; then
    echo "Building Dobby library..."
    cd jni/external/dobby
    mkdir -p build
    cd build
    
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI=arm64-v8a \
        -DANDROID_PLATFORM=android-31 \
        -DBUILD_SHARED_LIBS=OFF \
        -DDOBBY_DEBUG=OFF
    
    if [ $? -eq 0 ]; then
        cmake --build . --config Release
        echo "Dobby built successfully."
    else
        echo "Failed to configure Dobby build."
        exit 1
    fi
    cd ../../..
else
    echo "Dobby library already built."
fi

# Build the module
echo "Building module..."
cd jni
$ANDROID_NDK_ROOT/ndk-build \
    NDK_PROJECT_PATH=. \
    NDK_APPLICATION_MK=Application.mk \
    APP_BUILD_SCRIPT=Android.mk \
    APP_ABI=arm64-v8a \
    NDK_DEBUG=0

if [ $? -eq 0 ]; then
    echo "Module built successfully!"
    echo ""
    echo "Output files:"
    echo "- jni/libs/arm64-v8a/lsfbypass.so"
    echo ""
    echo "To create a Magisk module package:"
    echo "1. Create a directory structure with lib/arm64-v8a/"
    echo "2. Copy lsfbypass.so to lib/arm64-v8a/libsfbypass.so"
    echo "3. Add module.prop, zygisk_next.xml, sepolicy.rule, service.sh"
    echo "4. Zip the directory"
else
    echo "Failed to build module."
    exit 1
fi

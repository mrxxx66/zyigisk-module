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
    git checkout latest
    cd ../../..
else
    echo "Dobby library already cloned."
fi

# Apply Dobby fixes
echo "Applying Dobby fixes..."
chmod +x apply_dobby_fixes.sh
./apply_dobby_fixes.sh

# Build Dobby
if [ ! -f "jni/external/dobby/build/libdobby.a" ]; then
    echo "Building Dobby library..."
    cd jni/external/dobby
    mkdir -p build
    cd build
    
        # 为Android arm64-v8a构建Dobby静态库
        # 使用与主模块相同的工具链和平台设置
        # 添加 -DANDROID_TOOLCHAIN=clang 和 -DANDROID_LD=lld 以使用现代工具链
        echo "Configuring Dobby build with CMake..."
        cmake .. \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" \
            -DANDROID_ABI=arm64-v8a \
            -DANDROID_PLATFORM=android-31 \
            -DANDROID_STL=c++_static \
            -DANDROID_TOOLCHAIN=clang \
            -DANDROID_LD=lld \
            -DBUILD_SHARED_LIBS=OFF \
            -DDOBBY_DEBUG=OFF \
            -DDOBBY_EXAMPLE=OFF \
            -DDOBBY_TEST=OFF \
            -G Ninja
    
    if [ $? -eq 0 ]; then
        echo "Building Dobby..."
        cmake --build . --config Release --target dobby
        
        # 验证构建是否成功
        if [ -f "libdobby.a" ]; then
            echo "Found libdobby.a in build root directory"
        elif [ -f "source/libdobby.a" ]; then
            echo "Found libdobby.a in source/ directory"
            cp source/libdobby.a libdobby.a
        elif [ -f "builtin-plugin/libdobby.a" ]; then
            echo "Found libdobby.a in builtin-plugin/ directory"
            cp builtin-plugin/libdobby.a libdobby.a
        else
            echo "Error: libdobby.a not found after build"
            echo "Searching for any .a files:"
            find . -name "*.a" -type f
            exit 1
        fi
        
        # 确保库在期望的位置
        # 我们当前在 jni/external/dobby/build，libdobby.a 应该已经在这里
        if [ ! -f "libdobby.a" ]; then
          echo "Error: libdobby.a not created properly"
          exit 1
        fi
        echo "Dobby built successfully: $(pwd)/libdobby.a"
        echo "Library size: $(stat -c%s libdobby.a) bytes"
        
        # 验证库是有效的静态库
        if file libdobby.a | grep -q "ar archive"; then
          echo "Library verified as valid ar archive"
        else
          echo "Warning: libdobby.a doesn't appear to be a valid ar archive"
          file libdobby.a
        fi
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

# 验证libdobby.a是否存在
if [ ! -f "external/dobby/build/libdobby.a" ]; then
    echo "Error: libdobby.a not found at expected location"
    echo "Trying to find it..."
    find . -name "libdobby.a" -type f | head -5
    exit 1
fi

echo "Starting module build with ndk-build..."
echo "ANDROID_NDK_ROOT: $ANDROID_NDK_ROOT"
echo "Current directory: $(pwd)"

# 使用ndk-build，添加详细输出
$ANDROID_NDK_ROOT/ndk-build \
    NDK_PROJECT_PATH=. \
    NDK_APPLICATION_MK=Application.mk \
    APP_BUILD_SCRIPT=Android.mk \
    APP_ABI=arm64-v8a \
    APP_STL=c++_static \
    NDK_DEBUG=0 \
    V=1 2>&1 | tee build.log

# 检查构建结果
if [ $? -eq 0 ]; then
    echo "ndk-build completed successfully"
    echo ""
    echo "Module built successfully!"
    echo ""
    echo "Output files:"
    echo "- jni/libs/arm64-v8a/lsfbypass.so"
    echo ""
    echo "Build log saved to: jni/build.log"
    echo ""
    echo "To create a Magisk module package:"
    echo "1. Create a directory structure with lib/arm64-v8a/"
    echo "2. Copy lsfbypass.so to lib/arm64-v8a/libsfbypass.so"
    echo "3. Add module.prop, zygisk_next.xml, sepolicy.rule, service.sh"
    echo "4. Zip the directory"
else
    echo "ndk-build failed with exit code $?"
    echo "Build log (last 50 lines):"
    tail -50 build.log
    exit 1
fi

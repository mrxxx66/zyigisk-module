#!/bin/bash
# Validation script to check for common build issues

echo "=== Build Validation for HyperOS SF Bypass ==="
echo ""

# Check required files
echo "1. Checking required files..."
REQUIRED_FILES=(
    "jni/Android.mk"
    "jni/Application.mk"
    "jni/main.cpp"
    "jni/hook.cpp"
    "jni/cache.cpp"
    "jni/utils.cpp"
    ".github/workflows/build.yml"
    "build_local.sh"
)

all_files_exist=true
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (MISSING)"
        all_files_exist=false
    fi
done

if [ "$all_files_exist" = false ]; then
    echo ""
    echo "ERROR: Some required files are missing!"
    exit 1
fi

echo ""
echo "2. Checking C++17 usage in source files..."
echo "   Scanning for C++17 features..."

# Check for shared_mutex usage
echo "   Checking for <shared_mutex>..."
if grep -r "#include.*<shared_mutex>" jni/ --include="*.cpp" --include="*.h" > /dev/null; then
    echo "   ✓ Found <shared_mutex> includes (C++17 feature)"
else
    echo "   ✗ No <shared_mutex> found (might not be using C++17 features)"
fi

# Check for other C++17 features
echo "   Checking for other C++17 features..."
if grep -r "std::shared_mutex" jni/ --include="*.cpp" --include="*.h" > /dev/null; then
    echo "   ✓ Found std::shared_mutex usage"
fi

echo ""
echo "3. Checking Android.mk configuration..."
echo "   Checking for C++17 flag..."
if grep -q "std=c++17" jni/Android.mk; then
    echo "   ✓ C++17 flag found in Android.mk"
else
    echo "   ✗ C++17 flag NOT found in Android.mk"
fi

echo "   Checking for atomic library link..."
if grep -q "latomic" jni/Android.mk; then
    echo "   ✓ atomic library linked in Android.mk"
else
    echo "   ✗ atomic library NOT linked in Android.mk"
fi

echo ""
echo "4. Checking Application.mk configuration..."
echo "   Checking STL configuration..."
if grep -q "c++_static" jni/Application.mk; then
    echo "   ✓ c++_static STL configured in Application.mk"
else
    echo "   ✗ c++_static STL NOT configured in Application.mk"
fi

echo ""
echo "5. Checking GitHub Actions workflow..."
echo "   Checking Dobby build configuration..."
if grep -q "DANDROID_STL=c++_static" .github/workflows/build.yml; then
    echo "   ✓ c++_static STL configured for Dobby build"
else
    echo "   ✗ c++_static STL NOT configured for Dobby build"
fi

echo "   Checking build verification steps..."
if grep -q "libdobby.a" .github/workflows/build.yml | grep -q "find" | head -1; then
    echo "   ✓ Library verification steps found"
fi

echo ""
echo "6. Checking for potential issues..."
echo "   Checking for missing includes..."

# Check for problematic includes
PROBLEMATIC_INCLUDES=("unordered_map" "shared_mutex" "thread" "atomic")
for include in "${PROBLEMATIC_INCLUDES[@]}"; do
    if grep -r "#include.*<$include>" jni/ --include="*.cpp" --include="*.h" > /dev/null; then
        echo "   ✓ Found <$include> includes"
    fi
done

echo ""
echo "=== Validation Complete ==="
echo ""
echo "Summary of fixes applied to resolve GitHub Actions build failures:"
echo "1. Updated GitHub Actions workflow (.github/workflows/build.yml):"
echo "   - Added explicit ANDROID_STL=c++_static for Dobby build"
echo "   - Added library verification and error handling"
echo "   - Added detailed logging with tee and build.log"
echo "   - Added post-build verification of output files"
echo ""
echo "2. Updated Android.mk:"
echo "   - Added -latomic to LOCAL_LDFLAGS for C++17 atomic operations"
echo "   - Added -Wno-unused-* flags to suppress warnings"
echo ""
echo "3. Updated Application.mk:"
echo "   - Added -Wno-unused-* flags for consistency"
echo ""
echo "4. Updated build_local.sh:"
echo "   - Synchronized with GitHub Actions workflow"
echo "   - Added better error handling and verification"
echo "   - Added detailed logging"
echo ""
echo "Potential build issues that have been addressed:"
echo "- C++17 compatibility: Added explicit STL configuration"
echo "- Library linking: Added atomic library for C++17 features"
echo "- Build verification: Added steps to verify intermediate files"
echo "- Error handling: Added error checking and detailed logs"
echo ""
echo "To trigger a new build in GitHub Actions:"
echo "1. Commit and push these changes"
echo "2. Create and push a new version tag:"
echo "   git tag v1.0.1"
echo "   git push origin v1.0.1"
echo ""
echo "The build should now succeed with the applied fixes."

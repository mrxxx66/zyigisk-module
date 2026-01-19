# HyperOS SurfaceFlinger Screenshot Bypass (ZygiskNext Edition)

A ZygiskNext module that injects into the surfaceflinger process to bypass Xiaomi HyperOS (Android 13/14) screenshot restrictions by hooking `MiSurfaceFlingerStub::isCallingBySystemui`.

## Overview

This module hooks into the `surfaceflinger` process and intercepts calls to `android::MiSurfaceFlingerStub::isCallingBySystemui()`. When this function returns `false`, HyperOS blocks screenshot requests even if the app has `READ_FRAME_BUFFER` permission. This module makes it return `true` for whitelisted applications, effectively bypassing the restriction.

## Features

- **Zero-IO Hook Design**: All file operations are performed by a background thread; the hook function itself performs no I/O
- **Thread-Safe Cache**: Uses `std::shared_mutex` for high-performance concurrent access
- **Dynamic Whitelist**: Inotify-based monitoring of whitelist file changes
- **Safe Injection**: Only injects into the `surfaceflinger` process
* **SELinux Integration**: Proper SELinux policies for required permissions

## Prerequisites

- Android device with HyperOS (Android 13/14)
- Magisk with ZygiskNext support
- Android NDK r25c+ (for building)

## Project Structure

```
.
├── .github/workflows/build.yml   # GitHub Actions CI/CD configuration
├── jni/
│   ├── Android.mk                # NDK build configuration
│   ├── Application.mk            # NDK application configuration
│   ├── main.cpp                  # ZygiskNext entry point
│   ├── hook.cpp                  # Dobby inline hook implementation
│   ├── cache.cpp                 # Cache management and inotify monitor
│   └── utils.cpp                 # PID/UID to package name utilities
├── assets/
│   └── zygisk_next.xml           # ZygiskNext injection configuration
├── root/
│   ├── module.prop              # Module metadata
│   ├── sepolicy.rule            # SELinux policies
│   └── service.sh               # Module startup script
└── whitelist.txt                # Default whitelist template
```

## Building

### Manual Build

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/hyperos-sf-bypass.git
   cd hyperos-sf-bypass
   ```

2. Clone Dobby library:
   ```bash
   git clone https://github.com/jmpews/Dobby.git jni/external/dobby
   cd jni/external/dobby
   git checkout v2023.11.23
   cd ../..
   ```

3. Build Dobby:
   ```bash
   cd jni/external/dobby
   mkdir build && cd build
   cmake .. \
     -DCMAKE_BUILD_TYPE=Release \
     -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake \
     -DANDROID_ABI=arm64-v8a \
     -DANDROID_PLATFORM=android-31 \
     -DBUILD_SHARED_LIBS=OFF \
     -DDOBBY_DEBUG=OFF
   cmake --build . --config Release
   ```

4. Build the module:
   ```bash
   cd jni
   $ANDROID_NDK_ROOT/ndk-build \
     NDK_PROJECT_PATH=. \
     NDK_APPLICATION_MK=Application.mk \
     APP_BUILD_SCRIPT=Android.mk \
     APP_ABI=arm64-v8a \
     NDK_DEBUG=0
   ```

### Automated Build (GitHub Actions)

The repository includes GitHub Actions workflow that automatically:
- Builds when a version tag (`v*`) is pushed
- Creates a Magisk module ZIP package
- Publishes a GitHub release with the module

**To trigger a build**: Push a version tag (e.g., `git tag v1.0.0 && git push origin v1.0.0`)

## Installation

1. Download the latest release ZIP from the [Releases](https://github.com/yourusername/hyperos-sf-bypass/releases) page
2. Install via Magisk Manager or KernelSU app
3. Reboot your device
4. Edit `/data/adb/modules/hyperos_sf_bypass/whitelist.txt` to add your applications (one package name per line)

## Configuration

### Whitelist Format

The whitelist file (`/data/adb/modules/hyperos_sf_bypass/whitelist.txt`) contains package names, one per line:

```
# Whitelist for HyperOS SF Bypass
# Add one package name per line
# Examples:
com.android.systemui
com.miui.screenrecorder
com.example.yourapp
```

### Default Whitelist

By default, the following applications are whitelisted:

- `com.android.systemui` - System UI (for screenshots from power menu)
- `com.miui.screenrecorder` - MIUI Screen Recorder

## Technical Details

### Hooking Mechanism

The module hooks `_ZN7android21MiSurfaceFlingerStub19isCallingBySystemuiEi` in `libmisurfaceflinger.so` using Dobby inline hooking. When called:

1. Gets the real caller PID/UID using `IPCThreadState::self()->getCallingPid()/getCallingUid()`
2. Converts UID to package name by reading `/proc/[pid]/cmdline`
3. Checks if the package is in the whitelist
4. Returns `true` for whitelisted packages, `false` for others

### Performance Optimization

- **Memory Cache**: Uses `std::unordered_map<uid_t, bool>` for fast UID validation
- **Shared Mutex**: `std::shared_mutex` allows multiple concurrent readers
- **No I/O in Hook**: File operations are handled by a background inotify thread
- **Background Monitoring**: Whitelist changes are detected via inotify without polling

### SELinux Policies

The module includes SELinux policies to allow:
- SurfaceFlinger to access module files
- SurfaceFlinger to identify calling applications
- Binder identity verification

## Logging

The module logs to logcat with tag `SFBypass_ZNext`. Use the following command to monitor logs:

```bash
adb logcat -s SFBypass_ZNext
```

## Troubleshooting

### Module Doesn't Work

1. Check if the module is enabled in Magisk/KernelSU
2. Verify that `surfaceflinger` is running (should be, it's a core system service)
3. Check logs for any errors:
   ```bash
   adb logcat -s SFBypass_ZNext:E
   ```

### Permission Denied Errors

If you see SELinux denial messages, ensure the `sepolicy.rule` file is correctly installed and the device supports custom SELinux policies.

### Whitelist Not Working

1. Verify the whitelist file exists at `/data/adb/modules/hyperos_sf_bypass/whitelist.txt`
2. Check file permissions (should be 644)
3. Ensure package names are correct (case-sensitive)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This module is for educational purposes only. Use at your own risk. The developers are not responsible for any damage to your device or violation of terms of service.

## Credits

- [Dobby](https://github.com/jmpews/Dobby) - Dynamic instrumentation library
- [ZygiskNext](https://github.com/zygisk-next) - Zygisk implementation for KernelSU
- The Android and Magisk communities

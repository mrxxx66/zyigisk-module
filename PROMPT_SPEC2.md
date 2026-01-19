Final Specification: HyperOS SurfaceFlinger Screenshot Bypass (ZNext Edition)
1. Project Overview

Project Name: HyperOS-SF-Bypass

Target: Xiaomi HyperOS (Android 13/14)

Injection Framework: ZygiskNext (targeting non-zygote process: /system/bin/surfaceflinger)

Objective: Bypass the screenshot restriction by hooking MiSurfaceFlingerStub::isCallingBySystemui.

2. Core Hooking Logic (The "Brain")
A. Targeted Function

Library: libmisurfaceflinger.so

Function: android::MiSurfaceFlingerStub::isCallingBySystemui(int pid)

Mangled Symbol: _ZN7android21MiSurfaceFlingerStub19isCallingBySystemuiEi

Desired Outcome: Return true if the caller's package name exists in the local whitelist.

B. Implementation Strategy

Symbol Resolution:

Primary: Use DobbySymbolResolver to find the exported symbol.

Fallback: Implement a Hex Pattern Search within the memory segment of libmisurfaceflinger.so to find the function if the symbol is stripped.

Caller Identity:

Do NOT trust the pid argument blindly.

Use android::IPCThreadState::self()->getCallingPid() and getCallingUid() to verify the identity of the process requesting the screenshot.

3. High-Performance Architecture (Zero-Lag Design)

Since surfaceflinger is performance-critical (handles every frame), the hook must be ultra-fast:

Thread-Safe Memory Cache:

Use std::unordered_map<uid_t, bool> identity_cache to store validation results.

Use std::shared_mutex (C++17) to allow concurrent reads with minimal overhead.

Asynchronous Whitelist Monitor:

No File IO in Hook: Never use fopen or read inside the hooked function.

Inotify Thread: Spawn a background thread to watch /data/adb/modules/hyperos_sf_bypass/whitelist.txt. Update the memory cache only when the file changes.

PID to Package Mapping:

Use /proc/[pid]/cmdline or Binder-based getPackageForUid logic (if accessible) to resolve package names.

4. System & Security Integration
A. SELinux Policy (sepolicy.rule)

Crucial for preventing Permission Denied errors when SF tries to read our config or app cmdline:

code
Text
download
content_copy
expand_less
# Allow SF to access module directory
allow surfaceflinger magisk_file:dir { search };
allow surfaceflinger magisk_file:file { read open getattr };

# Allow SF to identify calling apps
allow surfaceflinger { untrusted_app priv_app platform_app system_app }:dir { search };
allow surfaceflinger { untrusted_app priv_app platform_app system_app }:file { read open getattr };

# Allow Binder identity checks
allow surfaceflinger self:capability { sys_ptrace };
B. ZygiskNext Configuration (zygisk_next.xml)
code
Xml
download
content_copy
expand_less
<zygisk_next>
    <process_name>surfaceflinger</process_name>
</zygisk_next>
5. Repository Structure & CI/CD
A. Directory Layout

jni/: C++ Source (main, hook, utils, whitelist_mgr).

jni/external/: Dobby library.

assets/: zygisk_next.xml.

root/: module.prop, service.sh, sepolicy.rule.

.github/workflows/build.yml: GitHub Actions config.

B. GitHub Actions Requirements

Use actions/checkout.

Setup Android NDK (r25c+).

Compile for arm64-v8a only.

Package into a .zip file with the following structure:

/lib/arm64-v8a/libxxx.so

/zygisk_next.xml

/module.prop

/sepolicy.rule

/service.sh

6. Development Instructions for Claude Code (The Prompt)

"Generate a professional ZygiskNext module using C++17 based on the specification above.

Process Guard: In onModuleLoaded, verify getprogname() is surfaceflinger before applying any hooks.

Dobby Hook: Implement a robust inline hook for isCallingBySystemui.

Performance: Implement the std::shared_mutex protected cache and an inotify background thread for whitelist updates.

Utility: Write a robust helper to convert PID to Package Name by reading /proc/pid/cmdline safely.

Packaging: Create the Android.mk or CMakeLists.txt for NDK build.

CI/CD: Create a build.yml for GitHub Actions that creates a release-ready Magisk zip when a version tag (v*) is pushed.

Logging: Use __android_log_print with tag SFBypass_ZNext for critical events only (initialization, hook status, whitelist hits)."

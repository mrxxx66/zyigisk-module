
Specification: HyperOS SurfaceFlinger Screenshot Bypass (ZygiskNext Edition)
1. Project Goal

开发一个基于 ZygiskNext 的原生模块，注入 surfaceflinger 进程，绕过小米 HyperOS (Android 13/14) 的私有截图权限限制，允许白名单应用捕获屏幕内容。

2. Technical Reverse Engineering Context

Target Process: /system/bin/surfaceflinger

Target Library: libmisurfaceflinger.so (可能位于 /system/lib64 或 /system_ext/lib64)

Key Function: android::MiSurfaceFlingerStub::isCallingBySystemui(int pid)

Mangled Symbol: _ZN7android21MiSurfaceFlingerStub19isCallingBySystemuiEi

Logic: 该函数返回 false 时，即使应用有 READ_FRAME_BUFFER 权限，SF 也会拦截截图请求。

3. Implementation Details (Native C++)
A. High-Performance Hooking

Identity Tracking: 内部使用 android::IPCThreadState::self()->getCallingPid() 获取可靠 PID。

Zero-IO Path: Hook 函数内禁止执行文件读写。所有判定必须基于内存缓存。

Thread-Safe Cache:

使用 std::unordered_map<uid_t, bool> identity_cache。

使用 std::shared_mutex 实现多读单写锁，确保 SF 高频调用下的性能。

Symbol Handling:

优先使用 dlsym 定位。

若失败，使用特征码扫描（建议搜索 MiSurfaceFlingerStub 构造函数附近的跳转表或特定的位运算逻辑）。

B. Configuration & Monitor

Whitelist Path: /data/adb/modules/hyperos_sf_bypass/whitelist.txt（每行一个包名）。

Inotify Thread: 启动一个后台线程监听文件变化，自动刷新内存中的 std::unordered_set<std::string> whitelist。

4. SELinux Policy (sepolicy.rule)

必须包含以下规则以确保注入后的 surfaceflinger 有权执行逻辑：

code
Text
download
content_copy
expand_less
# 允许访问模块文件
allow surfaceflinger magisk_file:dir { search };
allow surfaceflinger magisk_file:file { read open getattr };

# 允许读取应用进程信息
allow surfaceflinger { untrusted_app priv_app platform_app system_app }:dir { search };
allow surfaceflinger { untrusted_app priv_app platform_app system_app }:file { read open getattr };

# 允许调用者身份校验
allow surfaceflinger self:capability { sys_ptrace };
5. Repository & Project Structure

项目需符合 Magisk/ZygiskNext 模块规范：

code
Text
download
content_copy
expand_less
.
├── .github/workflows/build.yml   # GitHub Actions 配置
├── jni/
│   ├── Android.mk / CMakeLists.txt
│   ├── main.cpp                 # ZygiskNext 入口逻辑
│   ├── hook.cpp                 # Dobby Inline Hook
│   ├── cache.cpp                # 缓存与 Inotify 逻辑
│   └── utils.cpp                # PID/UID 转换包名工具
├── zygisk_next.xml              # ZygiskNext 注入配置文件
├── sepolicy.rule                # SELinux 规则
├── module.prop                  # 模块元数据
├── service.sh                   # 启动脚本
└── whitelist.txt                # 默认白名单模板
6. Build & CI/CD System (GitHub Actions)
A. Build Requirements

NDK: r25c 或更高。

Arch: 仅 arm64-v8a (SurfaceFlinger 运行环境)。

Libraries: 静态链接 Dobby 库。

B. CI Pipeline (build.yml)

Claude 需要生成的 GitHub Actions 脚本应包含：

Trigger: 推送 Tag 时自动触发构建。

Environment: 安装 Android NDK。

Compilation: 使用 ndk-build 或 cmake 编译生成 lsfbypass.so。

Packaging:

创建目录结构 lib/arm64-v8a/。

将 .so 放入对应目录。

复制 module.prop, zygisk_next.xml, sepolicy.rule, service.sh。

将整个结构打包为 HyperOS_SF_Bypass_vX.X.zip。

Release: 自动创建 GitHub Release 并上传 Zip 包。

7. Development Guidelines for Claude Code

Safety First: 在 onModuleLoaded 中通过 getprogname() 校验进程名。如果发现不是 surfaceflinger，立即退出，防止污染其他进程。

Robust Symbol Search: 生成的特征码搜索代码必须具备越界保护，搜索范围限定在 libmisurfaceflinger.so 的 .text 段内。

Graceful Fallback: 如果 Hook 失败，仅打印 logcat 警告，禁止执行 exit() 或导致进程崩溃的操作。

Logging: 使用 __android_log_print，Tag 统一为 SFBypass_ZNext。

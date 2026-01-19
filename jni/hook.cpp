#include <dlfcn.h>
#include <android/log.h>
#include <unistd.h>
#include <sys/mman.h>
#include <cstring>
#include <mutex>
#include <shared_mutex>
#include "dobby.h"

#define LOG_TAG "SFBypass_ZNext"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// IPCThreadState声明（用于获取真实的调用者PID）
extern "C" {
    class IPCThreadState {
    public:
        static IPCThreadState* self();
        pid_t getCallingPid();
        uid_t getCallingUid();
    };
}

// 目标函数类型
typedef bool (*isCallingBySystemui_t)(int pid);

// 原始函数指针
static isCallingBySystemui_t orig_isCallingBySystemui = nullptr;

// 导入缓存管理函数
extern bool is_package_in_whitelist(const char* package_name);
extern const char* get_package_name_from_uid(uid_t uid);
extern bool is_uid_in_cache(uid_t uid);
extern void update_uid_cache(uid_t uid, bool allowed);

// Hook替换函数
static bool hooked_isCallingBySystemui(int pid) {
    // 获取真实的调用者PID和UID
    IPCThreadState* ipc = IPCThreadState::self();
    if (!ipc) {
        LOGW("IPCThreadState::self() returned null, fallback to original");
        if (orig_isCallingBySystemui) {
            return orig_isCallingBySystemui(pid);
        }
        return false;
    }
    
    pid_t real_pid = ipc->getCallingPid();
    uid_t real_uid = ipc->getCallingUid();
    
    LOGD("isCallingBySystemui called with pid=%d, real_pid=%d, real_uid=%d", 
          pid, real_pid, real_uid);
    
    // 首先检查缓存
    if (is_uid_in_cache(real_uid)) {
        // 从缓存管理器获取结果
        const char* package_name = get_package_name_from_uid(real_uid);
        bool allowed = is_package_in_whitelist(package_name);
        LOGD("Cache hit for uid=%d, package=%s, allowed=%d", 
              real_uid, package_name ? package_name : "unknown", allowed);
        return allowed;
    }
    
    // 获取包名并检查白名单
    const char* package_name = get_package_name_from_uid(real_uid);
    if (!package_name) {
        LOGW("Failed to get package name for uid=%d, fallback to original", real_uid);
        if (orig_isCallingBySystemui) {
            return orig_isCallingBySystemui(pid);
        }
        return false;
    }
    
    bool allowed = is_package_in_whitelist(package_name);
    
    // 更新缓存
    update_uid_cache(real_uid, allowed);
    
    LOGD("Package %s (uid=%d) is %s in whitelist", 
          package_name, real_uid, allowed ? "" : "not");
    
    return allowed;
}

// 特征码搜索函数
static void* find_function_by_pattern(void* library_base, const char* pattern, const char* mask) {
    // 获取库的内存信息
    Dl_info info;
    if (dladdr(library_base, &info) == 0) {
        LOGE("Failed to get library info");
        return nullptr;
    }
    
    // 这里实现特征码搜索逻辑
    // 注意：这是一个简化的实现，实际中需要更复杂的特征码搜索
    LOGW("Pattern search not fully implemented, using fallback");
    return nullptr;
}

// 初始化Hook
void initialize_hook() {
    LOGI("Initializing hook for MiSurfaceFlingerStub::isCallingBySystemui");
    
    // 尝试加载目标库
    void* handle = dlopen("libmisurfaceflinger.so", RTLD_NOW | RTLD_LOCAL);
    if (!handle) {
        // 尝试其他路径
        handle = dlopen("/system/lib64/libmisurfaceflinger.so", RTLD_NOW | RTLD_LOCAL);
        if (!handle) {
            handle = dlopen("/system_ext/lib64/libmisurfaceflinger.so", RTLD_NOW | RTLD_LOCAL);
        }
    }
    
    if (!handle) {
        LOGE("Failed to load libmisurfaceflinger.so: %s", dlerror());
        return;
    }
    
    LOGI("Successfully loaded libmisurfaceflinger.so");
    
    // 尝试获取符号
    const char* symbol_name = "_ZN7android21MiSurfaceFlingerStub19isCallingBySystemuiEi";
    void* target_func = dlsym(handle, symbol_name);
    
    if (!target_func) {
        LOGW("Symbol %s not found, trying pattern search", symbol_name);
        // 尝试特征码搜索
        // 这里需要根据实际函数特征码实现
        // target_func = find_function_by_pattern(handle, pattern, mask);
    }
    
    if (!target_func) {
        LOGE("Failed to locate target function");
        dlclose(handle);
        return;
    }
    
    LOGI("Found target function at %p", target_func);
    
    // 使用Dobby进行Hook
    if (DobbyHook(target_func, (void*)hooked_isCallingBySystemui, 
                  (void**)&orig_isCallingBySystemui) != 0) {
        LOGE("DobbyHook failed");
        dlclose(handle);
        return;
    }
    
    LOGI("Successfully hooked MiSurfaceFlingerStub::isCallingBySystemui");
    LOGI("Original function at %p, Hooked function at %p", 
          orig_isCallingBySystemui, hooked_isCallingBySystemui);
    
    // 不要关闭句柄，因为我们需要库保持加载状态
}

// 清理Hook资源
void cleanup_hook() {
    // 如果有必要，这里可以恢复Hook
    // 但通常ZygiskNext会在进程退出时自动清理
    LOGI("Hook cleanup completed");
}

#include <jni.h>
#include <string>
#include <android/log.h>
#include <unistd.h>
#include <dlfcn.h>
#include "dobby.h"

#define LOG_TAG "SFBypass_ZNext"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// 声明其他模块函数
extern void initialize_hook();
extern void initialize_cache_manager();
extern void cleanup_resources();

// 获取进程名称
static const char* get_process_name() {
    static char process_name[256] = {0};
    if (process_name[0] == '\0') {
        char path[64];
        snprintf(path, sizeof(path), "/proc/%d/cmdline", getpid());
        FILE* cmdline = fopen(path, "r");
        if (cmdline) {
            fgets(process_name, sizeof(process_name), cmdline);
            fclose(cmdline);
            // 提取基本名称
            char* base = strrchr(process_name, '/');
            if (base) {
                return base + 1;
            }
        }
    }
    return process_name;
}

// ZygiskNext模块加载入口
extern "C" [[gnu::visibility("default")]] [[gnu::used]]
void onModuleLoaded() {
    const char* proc_name = get_process_name();
    LOGI("Module loaded in process: %s (PID: %d)", proc_name, getpid());
    
    // 只注入surfaceflinger进程
    if (strcmp(proc_name, "surfaceflinger") != 0) {
        LOGI("Not surfaceflinger, exiting module");
        return;
    }
    
    LOGI("Initializing HyperOS SF Bypass for surfaceflinger");
    
    // 初始化缓存管理器
    initialize_cache_manager();
    
    // 初始化Hook
    initialize_hook();
    
    LOGI("HyperOS SF Bypass initialization complete");
}

// 清理函数（如果需要）
extern "C" [[gnu::visibility("default")]] [[gnu::used]]
void onModuleUnloaded() {
    const char* proc_name = get_process_name();
    if (strcmp(proc_name, "surfaceflinger") == 0) {
        LOGI("Cleaning up HyperOS SF Bypass resources");
        cleanup_resources();
    }
}

// JNI入口点（如果需要）
extern "C" JNIEXPORT jstring JNICALL
Java_com_example_sfbypass_MainActivity_stringFromJNI(
        JNIEnv* env,
        jobject /* this */) {
    std::string hello = "Hello from HyperOS SF Bypass";
    return env->NewStringUTF(hello.c_str());
}

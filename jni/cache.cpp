#include <unordered_map>
#include <unordered_set>
#include <shared_mutex>
#include <thread>
#include <atomic>
#include <string>
#include <vector>
#include <fstream>
#include <sys/inotify.h>
#include <unistd.h>
#include <android/log.h>
#include <cstring>

#define LOG_TAG "SFBypass_ZNext"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// 全局缓存和数据结构
static std::unordered_map<uid_t, bool> identity_cache;
static std::unordered_set<std::string> whitelist;
static std::shared_mutex cache_mutex;
static std::shared_mutex whitelist_mutex;
static std::atomic<bool> monitor_running{false};
static std::thread monitor_thread;
static int inotify_fd = -1;
static int watch_fd = -1;

// 模块路径（由service.sh设置）
const char* module_dir = nullptr;

// 获取白名单文件路径
static std::string get_whitelist_path() {
    if (module_dir) {
        return std::string(module_dir) + "/whitelist.txt";
    }
    // 默认路径
    return "/data/adb/modules/hyperos_sf_bypass/whitelist.txt";
}

// 加载白名单文件
static void load_whitelist() {
    std::string path = get_whitelist_path();
    std::ifstream file(path);
    
    if (!file.is_open()) {
        LOGW("Could not open whitelist file: %s", path.c_str());
        return;
    }
    
    std::unordered_set<std::string> new_whitelist;
    std::string line;
    int count = 0;
    
    while (std::getline(file, line)) {
        // 跳过注释行和空行
        if (line.empty() || line[0] == '#') {
            continue;
        }
        
        // 去除前后空白
        size_t start = line.find_first_not_of(" \t");
        size_t end = line.find_last_not_of(" \t");
        if (start != std::string::npos && end != std::string::npos) {
            std::string package = line.substr(start, end - start + 1);
            if (!package.empty()) {
                new_whitelist.insert(package);
                count++;
            }
        }
    }
    
    file.close();
    
    // 使用写锁更新白名单
    {
        std::unique_lock lock(whitelist_mutex);
        whitelist.swap(new_whitelist);
    }
    
    // 清空缓存，因为白名单已更改
    {
        std::unique_lock lock(cache_mutex);
        identity_cache.clear();
    }
    
    LOGI("Loaded %d package(s) into whitelist from %s", count, path.c_str());
}

// 检查包是否在白名单中
bool is_package_in_whitelist(const char* package_name) {
    if (!package_name) {
        return false;
    }
    
    // 使用读锁检查白名单
    std::shared_lock lock(whitelist_mutex);
    return whitelist.find(package_name) != whitelist.end();
}

// 检查UID是否在缓存中
bool is_uid_in_cache(uid_t uid) {
    std::shared_lock lock(cache_mutex);
    return identity_cache.find(uid) != identity_cache.end();
}

// 更新UID缓存
void update_uid_cache(uid_t uid, bool allowed) {
    std::unique_lock lock(cache_mutex);
    identity_cache[uid] = allowed;
}

// 根据UID获取包名（外部定义，在utils.cpp中实现）
extern const char* get_package_name_from_uid(uid_t uid);

// Inotify监控线程函数
static void whitelist_monitor() {
    inotify_fd = inotify_init();
    if (inotify_fd < 0) {
        LOGE("Failed to initialize inotify: %s", strerror(errno));
        return;
    }
    
    std::string path = get_whitelist_path();
    watch_fd = inotify_add_watch(inotify_fd, path.c_str(), 
                                 IN_MODIFY | IN_CLOSE_WRITE | IN_MOVE_SELF | IN_DELETE_SELF);
    
    if (watch_fd < 0) {
        LOGE("Failed to add inotify watch for %s: %s", path.c_str(), strerror(errno));
        close(inotify_fd);
        inotify_fd = -1;
        return;
    }
    
    LOGI("Started inotify monitor for %s", path.c_str());
    
    char buffer[4096] __attribute__((aligned(__alignof__(struct inotify_event))));
    
    while (monitor_running) {
        fd_set fds;
        FD_ZERO(&fds);
        FD_SET(inotify_fd, &fds);
        
        struct timeval timeout;
        timeout.tv_sec = 1;
        timeout.tv_usec = 0;
        
        int ret = select(inotify_fd + 1, &fds, nullptr, nullptr, &timeout);
        
        if (ret > 0 && FD_ISSET(inotify_fd, &fds)) {
            ssize_t len = read(inotify_fd, buffer, sizeof(buffer));
            if (len > 0) {
                // 文件发生变化，重新加载白名单
                LOGI("Whitelist file changed, reloading...");
                load_whitelist();
            }
        }
    }
    
    // 清理inotify
    if (watch_fd >= 0) {
        inotify_rm_watch(inotify_fd, watch_fd);
    }
    if (inotify_fd >= 0) {
        close(inotify_fd);
    }
    
    LOGI("Whitelist monitor stopped");
}

// 初始化缓存管理器
void initialize_cache_manager() {
    // 尝试从环境变量获取模块目录
    module_dir = getenv("HYPEROS_SF_BYPASS_MODULE_DIR");
    if (!module_dir) {
        module_dir = "/data/adb/modules/hyperos_sf_bypass";
        LOGW("HYPEROS_SF_BYPASS_MODULE_DIR not set, using default: %s", module_dir);
    }
    
    LOGI("Initializing cache manager with module dir: %s", module_dir);
    
    // 初始加载白名单
    load_whitelist();
    
    // 启动inotify监控线程
    monitor_running = true;
    monitor_thread = std::thread(whitelist_monitor);
    
    LOGI("Cache manager initialized");
}

// 清理缓存管理器资源
void cleanup_cache_manager() {
    LOGI("Cleaning up cache manager");
    
    // 停止监控线程
    monitor_running = false;
    if (monitor_thread.joinable()) {
        monitor_thread.join();
    }
    
    // 清理缓存
    {
        std::unique_lock lock1(cache_mutex);
        std::unique_lock lock2(whitelist_mutex);
        identity_cache.clear();
        whitelist.clear();
    }
    
    LOGI("Cache manager cleanup completed");
}

// 主清理函数（供外部调用）
void cleanup_resources() {
    cleanup_cache_manager();
    // 注意：hook的清理在hook.cpp中完成
}

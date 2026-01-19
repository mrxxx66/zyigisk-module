#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>
#include <pthread.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <android/log.h>
#include <unordered_map>
#include <shared_mutex>
#include <string>

#define LOG_TAG "SFBypass_ZNext"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// 包名缓存
static std::unordered_map<uid_t, std::string> package_cache;
static std::shared_mutex package_cache_mutex;

// 安全读取/proc/pid/cmdline文件
static char* read_cmdline_safe(pid_t pid) {
    char path[64];
    snprintf(path, sizeof(path), "/proc/%d/cmdline", pid);
    
    int fd = open(path, O_RDONLY);
    if (fd < 0) {
        LOGW("Failed to open %s for reading", path);
        return nullptr;
    }
    
    // 读取cmdline
    char buffer[1024];
    ssize_t bytes_read = read(fd, buffer, sizeof(buffer) - 1);
    close(fd);
    
    if (bytes_read <= 0) {
        LOGW("Failed to read cmdline for pid %d", pid);
        return nullptr;
    }
    
    // 确保以null结尾
    buffer[bytes_read] = '\0';
    
    // 复制字符串
    char* result = static_cast<char*>(malloc(bytes_read + 1));
    if (result) {
        memcpy(result, buffer, bytes_read + 1);
    }
    
    return result;
}

// 从cmdline中提取包名
static const char* extract_package_name(const char* cmdline) {
    if (!cmdline) {
        return nullptr;
    }
    
    // cmdline通常包含进程的完整路径，如com.package.name:process_name
    // 我们只需要包名部分
    
    // 查找冒号分隔符
    const char* colon = strchr(cmdline, ':');
    if (colon) {
        // 返回冒号前的部分（包名）
        size_t len = colon - cmdline;
        char* package = static_cast<char*>(malloc(len + 1));
        if (package) {
            strncpy(package, cmdline, len);
            package[len] = '\0';
            return package;
        }
    }
    
    // 如果没有冒号，尝试作为包名直接返回
    char* package = strdup(cmdline);
    return package;
}

// 根据UID获取包名
const char* get_package_name_from_uid(uid_t uid) {
    // 首先检查缓存
    {
        std::shared_lock lock(package_cache_mutex);
        auto it = package_cache.find(uid);
        if (it != package_cache.end()) {
            return it->second.c_str();
        }
    }
    
    // 将UID转换为PID（这里假设UID就是应用的用户ID）
    // 在实际实现中，可能需要更复杂的映射
    // 这里我们通过读取/proc目录来查找属于该UID的进程
    
    pid_t target_pid = -1;
    DIR* proc_dir = opendir("/proc");
    if (!proc_dir) {
        LOGW("Failed to open /proc directory");
        return nullptr;
    }
    
    struct dirent* entry;
    while ((entry = readdir(proc_dir)) != nullptr) {
        // 检查是否为数字目录（进程）
        if (entry->d_type != DT_DIR) {
            continue;
        }
        
        char* endptr;
        pid_t pid = strtol(entry->d_name, &endptr, 10);
        if (*endptr != '\0') {
            continue;
        }
        
        // 读取进程状态获取UID
        char status_path[128];
        snprintf(status_path, sizeof(status_path), "/proc/%d/status", pid);
        
        FILE* status_file = fopen(status_path, "r");
        if (!status_file) {
            continue;
        }
        
        uid_t proc_uid = 0;
        char line[256];
        while (fgets(line, sizeof(line), status_file)) {
            if (strncmp(line, "Uid:", 4) == 0) {
                // 格式: Uid: real effective saved filesystem
                sscanf(line + 4, "%u", &proc_uid);
                break;
            }
        }
        fclose(status_file);
        
        if (proc_uid == uid) {
            target_pid = pid;
            break;
        }
    }
    closedir(proc_dir);
    
    if (target_pid == -1) {
        LOGW("No process found for uid %d", uid);
        return nullptr;
    }
    
    // 读取进程的cmdline
    char* cmdline = read_cmdline_safe(target_pid);
    if (!cmdline) {
        LOGW("Failed to read cmdline for pid %d (uid %d)", target_pid, uid);
        return nullptr;
    }
    
    // 提取包名
    const char* package_name = extract_package_name(cmdline);
    free(cmdline);
    
    if (!package_name) {
        LOGW("Failed to extract package name for uid %d", uid);
        return nullptr;
    }
    
    // 更新缓存
    {
        std::unique_lock lock(package_cache_mutex);
        package_cache[uid] = package_name;
    }
    
    LOGD("Mapped uid %d to package %s", uid, package_name);
    
    // 注意：这里分配的内存由cache持有，直到程序结束
    // 在实际实现中可能需要更好的内存管理
    return package_cache[uid].c_str();
}

// 获取调用者PID（替代方案，如果IPCThreadState不可用）
pid_t get_caller_pid_fallback() {
    // 通过读取/proc/self/task/pid/status来获取调用者信息
    // 这是一个简化的实现
    static __thread pid_t cached_tid = 0;
    if (cached_tid == 0) {
        cached_tid = gettid();
    }
    
    // 这里可以实现更复杂的逻辑来获取Binder调用者信息
    // 但为了简单起见，我们返回当前线程ID
    return cached_tid;
}

// 工具函数：检查文件是否存在
bool file_exists(const char* path) {
    struct stat st;
    return stat(path, &st) == 0;
}

// 工具函数：安全读取文件内容到字符串
std::string read_file_to_string(const char* path) {
    FILE* file = fopen(path, "r");
    if (!file) {
        return "";
    }
    
    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    fseek(file, 0, SEEK_SET);
    
    std::string content(size, '\0');
    fread(&content[0], 1, size, file);
    fclose(file);
    
    return content;
}

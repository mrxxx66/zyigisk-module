LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

# 模块名称
LOCAL_MODULE := lsfbypass

# 源文件
LOCAL_SRC_FILES := \
    main.cpp \
    hook.cpp \
    cache.cpp \
    utils.cpp

# C++标准
LOCAL_CPPFLAGS := -std=c++17 -frtti -fexceptions
LOCAL_CFLAGS := -DANDROID -DLOG_TAG=\"SFBypass_ZNext\"

# Dobby头文件路径
LOCAL_C_INCLUDES := \
    $(LOCAL_PATH)/external/dobby/include \
    $(LOCAL_PATH)/external/dobby/builtin-plugin

# 预构建的Dobby静态库
LOCAL_STATIC_LIBRARIES := dobby

# 链接库
LOCAL_LDLIBS := -llog -landroid

include $(BUILD_SHARED_LIBRARY)

# 包含Dobby静态库
include $(CLEAR_VARS)
LOCAL_MODULE := dobby
LOCAL_SRC_FILES := external/dobby/build/libdobby.a
include $(PREBUILT_STATIC_LIBRARY)

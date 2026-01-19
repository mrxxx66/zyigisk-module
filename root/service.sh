#!/system/bin/sh

# 此脚本在模块加载时执行
# 用于设置环境变量或执行其他初始化操作

MODDIR=${0%/*}

# 设置模块路径，以便surfaceflinger进程可以找到配置文件
export HYPEROS_SF_BYPASS_MODULE_DIR="$MODDIR"

# 确保白名单文件存在
if [ ! -f "$MODDIR/whitelist.txt" ]; then
    # 创建默认白名单文件（如果不存在）
    echo "# Whitelist for HyperOS SF Bypass" > "$MODDIR/whitelist.txt"
    echo "# Add one package name per line" >> "$MODDIR/whitelist.txt"
    echo "# Examples:" >> "$MODDIR/whitelist.txt"
    echo "# com.android.systemui" >> "$MODDIR/whitelist.txt"
    echo "# com.miui.screenrecorder" >> "$MODDIR/whitelist.txt"
    chmod 644 "$MODDIR/whitelist.txt"
fi

# 打印启动日志
log -t "SFBypass_ZNext" "HyperOS SF Bypass module loaded"

# PowerShell script to apply Dobby fixes

Write-Host "Applying Dobby fixes..." -ForegroundColor Green

$DOBBY_DIR = "jni/external/dobby"

# 1. 修复ARM64汇编文件中的平台条件编译
$ASM_FILE = "$DOBBY_DIR/source/TrampolineBridge/ClosureTrampolineBridge/arm64/closure_bridge_arm64.asm"
if (Test-Path $ASM_FILE) {
    Write-Host "Fixing ARM64 assembly file..." -ForegroundColor Yellow
    # 备份原始文件
    Copy-Item $ASM_FILE "$ASM_FILE.bak" -Force
    
    # 应用修复 - 添加平台条件编译
    $asmContent = @'
//===-- closure_bridge_arm64.asm - ARM64 closure trampoline bridge --------===//
//
// Part of the Dobby Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "TrampolineBridge/ClosureTrampolineBridge/common_bridge_handler.h"

.text
.align 4
.global cdecl(common_closure_bridge)
cdecl(common_closure_bridge):
  // save general purpose registers
  stp x0, x1, [sp, #-16]!
  stp x2, x3, [sp, #-16]!
  stp x4, x5, [sp, #-16]!
  stp x6, x7, [sp, #-16]!
  stp x8, x9, [sp, #-16]!
  stp x10, x11, [sp, #-16]!
  stp x12, x13, [sp, #-16]!
  stp x14, x15, [sp, #-16]!
  stp x16, x17, [sp, #-16]!
  stp x18, x19, [sp, #-16]!
  stp x20, x21, [sp, #-16]!
  stp x22, x23, [sp, #-16]!
  stp x24, x25, [sp, #-16]!
  stp x26, x27, [sp, #-16]!
  stp x28, x29, [sp, #-16]!
  stp x30, xzr, [sp, #-16]!

  // save floating point registers
  stp q0, q1, [sp, #-32]!
  stp q2, q3, [sp, #-32]!
  stp q4, q5, [sp, #-32]!
  stp q6, q7, [sp, #-32]!
  stp q8, q9, [sp, #-32]!
  stp q10, q11, [sp, #-32]!
  stp q12, q13, [sp, #-32]!
  stp q14, q15, [sp, #-32]!
  stp q16, q17, [sp, #-32]!
  stp q18, q19, [sp, #-32]!
  stp q20, q21, [sp, #-32]!
  stp q22, q23, [sp, #-32]!
  stp q24, q25, [sp, #-32]!
  stp q26, q27, [sp, #-32]!
  stp q28, q29, [sp, #-32]!
  stp q30, q31, [sp, #-32]!

  // call common_closure_bridge_handler
#if defined(__APPLE__)
  // macOS/iOS syntax
  adrp TMP_REG_0, cdecl(common_closure_bridge_handler)@PAGE
  add TMP_REG_0, TMP_REG_0, cdecl(common_closure_bridge_handler)@PAGEOFF
#else
  // Linux/Android syntax - load address from .data section
  adrp TMP_REG_0, common_closure_bridge_handler_addr
  ldr TMP_REG_0, [TMP_REG_0, :lo12:common_closure_bridge_handler_addr]
#endif
  blr TMP_REG_0

  // restore floating point registers
  ldp q30, q31, [sp], #32
  ldp q28, q29, [sp], #32
  ldp q26, q27, [sp], #32
  ldp q24, q25, [sp], #32
  ldp q22, q23, [sp], #32
  ldp q20, q21, [sp], #32
  ldp q18, q19, [sp], #32
  ldp q16, q17, [sp], #32
  ldp q14, q15, [sp], #32
  ldp q12, q13, [sp], #32
  ldp q10, q11, [sp], #32
  ldp q8, q9, [sp], #32
  ldp q6, q7, [sp], #32
  ldp q4, q5, [sp], #32
  ldp q2, q3, [sp], #32
  ldp q0, q1, [sp], #32

  // restore general purpose registers
  ldp x30, xzr, [sp], #16
  ldp x28, x29, [sp], #16
  ldp x26, x27, [sp], #16
  ldp x24, x25, [sp], #16
  ldp x22, x23, [sp], #16
  ldp x20, x21, [sp], #16
  ldp x18, x19, [sp], #16
  ldp x16, x17, [sp], #16
  ldp x14, x15, [sp], #16
  ldp x12, x13, [sp], #16
  ldp x10, x11, [sp], #16
  ldp x8, x9, [sp], #16
  ldp x6, x7, [sp], #16
  ldp x4, x5, [sp], #16
  ldp x2, x3, [sp], #16
  ldp x0, x1, [sp], #16

  ret

.data
.align 3
.global common_closure_bridge_handler_addr
common_closure_bridge_handler_addr:
  .quad cdecl(common_closure_bridge_handler)
'@
    Set-Content -Path $ASM_FILE -Value $asmContent
    Write-Host "ARM64 assembly file fixed" -ForegroundColor Green
} else {
    Write-Host "Warning: ARM64 assembly file not found: $ASM_FILE" -ForegroundColor Yellow
}

# 2. 修复ProcessRuntime.cc中的比较器函数
$PROCESS_RUNTIME_FILE = "$DOBBY_DIR/source/Backend/UserMode/PlatformUtil/Linux/ProcessRuntime.cc"
if (Test-Path $PROCESS_RUNTIME_FILE) {
    Write-Host "Fixing ProcessRuntime.cc..." -ForegroundColor Yellow
    # 备份原始文件
    Copy-Item $PROCESS_RUNTIME_FILE "$PROCESS_RUNTIME_FILE.bak" -Force
    
    # 读取文件内容并替换
    $content = Get-Content $PROCESS_RUNTIME_FILE -Raw
    $content = $content -replace 'return \(a\.start < b\.start\);', 'return (a.start() < b.start());'
    Set-Content -Path $PROCESS_RUNTIME_FILE -Value $content
    Write-Host "ProcessRuntime.cc fixed" -ForegroundColor Green
} else {
    Write-Host "Warning: ProcessRuntime.cc not found: $PROCESS_RUNTIME_FILE" -ForegroundColor Yellow
}

# 3. 修复循环依赖问题 - 修改platform.h
$PLATFORM_H_FILE = "$DOBBY_DIR/source/PlatformUnifiedInterface/platform.h"
if (Test-Path $PLATFORM_H_FILE) {
    Write-Host "Fixing platform.h to break circular dependency..." -ForegroundColor Yellow
    # 备份原始文件
    Copy-Item $PLATFORM_H_FILE "$PLATFORM_H_FILE.bak" -Force
    
    # 应用修复 - 移除对common.h的包含，添加标准库头文件
    $platformContent = @'
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstdarg>

namespace dobby {

enum MemoryPermission {
  kNoAccess,
  kRead,
  kReadWrite,
  kReadExecute,
  kReadWriteExecute,
  kReadExecuteWrite, // for iOS
};

class OSMemory {
public:
  static int PageSize();

  static void *Allocate(size_t size, MemoryPermission permission);

  static void *AllocateNear(void *address, size_t size, size_t search_range, MemoryPermission permission);

  static void Free(void *address, size_t size);

  static bool SetPermission(void *address, size_t size, MemoryPermission permission);

  static MemoryPermission GetPermission(void *address, size_t size);

  static void *Reserve(size_t size);

  static bool Release(void *address, size_t size);

  static void FlushInstructionCache(void *address, size_t size);
};

} // namespace dobby
'@
    Set-Content -Path $PLATFORM_H_FILE -Value $platformContent
    Write-Host "platform.h fixed" -ForegroundColor Green
} else {
    Write-Host "Warning: platform.h not found: $PLATFORM_H_FILE" -ForegroundColor Yellow
}

# 4. 修复循环依赖问题 - 修改os_arch_features.h
$OS_ARCH_FEATURES_FILE = "$DOBBY_DIR/common/os_arch_features.h"
if (Test-Path $OS_ARCH_FEATURES_FILE) {
    Write-Host "Fixing os_arch_features.h..." -ForegroundColor Yellow
    # 备份原始文件
    Copy-Item $OS_ARCH_FEATURES_FILE "$OS_ARCH_FEATURES_FILE.bak" -Force
    
    # 应用修复 - 直接包含platform.h
    $osArchContent = @'
#pragma once

#include <sys/types.h>
#include <stddef.h>
#include "pac_kit.h"
#include "../source/PlatformUnifiedInterface/platform.h"

namespace dobby {

static inline bool make_memory_readable(void *address, size_t size) {
  return OSMemory::SetPermission(address, size, kReadExecute);
}

static inline bool make_memory_writable(void *address, size_t size) {
  return OSMemory::SetPermission(address, size, kReadWrite);
}

static inline bool make_memory_executable(void *address, size_t size) {
  return OSMemory::SetPermission(address, size, kReadExecute);
}

} // namespace dobby
'@
    Set-Content -Path $OS_ARCH_FEATURES_FILE -Value $osArchContent
    Write-Host "os_arch_features.h fixed" -ForegroundColor Green
} else {
    Write-Host "Warning: os_arch_features.h not found: $OS_ARCH_FEATURES_FILE" -ForegroundColor Yellow
}

# 5. 修复CMakeLists.txt以链接osbase和logging库
$CMAKE_FILE = "$DOBBY_DIR/CMakeLists.txt"
if (Test-Path $CMAKE_FILE) {
    Write-Host "Fixing CMakeLists.txt to link osbase and logging libraries..." -ForegroundColor Yellow
    # 备份原始文件
    Copy-Item $CMAKE_FILE "$CMAKE_FILE.bak" -Force
    
    # 读取文件内容
    $cmakeContent = Get-Content $CMAKE_FILE -Raw
    
    # 检查是否已经修复
    if ($cmakeContent -notmatch 'target_link_libraries\(dobby osbase logging\)') {
        # 在适当的位置添加链接
        $cmakeContent = $cmakeContent -replace '(add_library\(dobby_static STATIC \$\{DOBBY_SRC\}\))', "`$1`n# Link required libraries`ntarget_link_libraries(dobby osbase logging)`n# Also link osbase and logging to static library`ntarget_link_libraries(dobby_static osbase logging)"
        Set-Content -Path $CMAKE_FILE -Value $cmakeContent
        Write-Host "CMakeLists.txt fixed" -ForegroundColor Green
    } else {
        Write-Host "CMakeLists.txt already fixed" -ForegroundColor Green
    }
} else {
    Write-Host "Warning: CMakeLists.txt not found: $CMAKE_FILE" -ForegroundColor Yellow
}

Write-Host "All Dobby fixes applied successfully!" -ForegroundColor Green

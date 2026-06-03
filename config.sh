#!/bin/bash
# config.sh - Configuration for GKI Kernel Builder

# ==========================================
# 1. Project Configuration
# ==========================================
KERNEL_NAME="FleurX-GKI"
KERNEL_SOURCE="https://github.com/zylhdrXP/android_kernel_common-5.10"
KERNEL_BRANCH="android12-5.10"
KBUILD_USER="heydr"
KBUILD_HOST="zylhdrxp"
TIMEZONE="Asia/Jakarta"

# ==========================================
# 2. AnyKernel3 Configuration
# ==========================================
ANYKERNEL_REPO="https://github.com/zylhdrXP/AnyKernel3"
ANYKERNEL_BRANCH="gki"

# ==========================================
# 3. Toolchain Configuration
# ==========================================
CLANG_URL="https://github.com/greenforce-project/greenforce_clang/releases/download/20260601/gf-clang-23.0.0-20260601.tar.gz"

# ==========================================
# 4. GitHub Release Configuration
# ==========================================
RELEASE_REPO="zylhdrXP/FleurX-GKI-Release"

# ==========================================
# 5. Default Build Options
# ==========================================
# Options: Vanilla, KSUN_SUSFS
DEFAULT_VARIANT="Vanilla"
# Options: CI, Release
DEFAULT_RELEASE_TYPE="CI"

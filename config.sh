#!/bin/bash
# config.sh - Configuration for GKI Kernel Builder

# ==========================================
# 1. Project Configuration
# ==========================================
KERNEL_NAME="FleurX-GKI"
KERNEL_SOURCE="https://github.com/zylhdrXP/android_kernel_common-5.10"
KERNEL_BRANCH="linux-stable"
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
CLANG_URL="https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/download/03062026/neutron-clang-03062026.tar.zst"

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

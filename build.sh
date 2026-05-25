#!/bin/bash
# build.sh - GKI Kernel Builder (5.10 Only)

set -e

if [ ! -f "config.sh" ]; then
    echo "Error: config.sh not found!"
    exit 1
fi
source config.sh

# Inputs
VARIANT=${1:-$DEFAULT_VARIANT}
RELEASE_TYPE=${2:-$DEFAULT_RELEASE_TYPE}

WORKDIR="$(pwd)"
OUTDIR="$WORKDIR/out"
KSRC="$WORKDIR/ksrc"

# Kernel Configuration
if [ "$RELEASE_TYPE" == "Release" ]; then
    if command -v gh &> /dev/null && [ -n "$GH_TOKEN" ]; then
        # Query the latest release tag (e.g., v1.0)
        LATEST_TAG=$(gh api repos/"$RELEASE_REPO"/releases/latest --jq '.tag_name' 2>/dev/null || true)
        if [ -z "$LATEST_TAG" ]; then
            RELEASE="v1.0"
        else
            # Extract major and minor version and increment minor
            MAJOR=$(echo "$LATEST_TAG" | grep -oP 'v\K\d+' || echo "1")
            MINOR=$(echo "$LATEST_TAG" | grep -oP '\.\K\d+' || echo "0")
            RELEASE="v${MAJOR}.$((MINOR + 1))"
        fi
    else
        RELEASE="v1.0"
    fi
else
    # No versioning in CI, just use a date stamp
    RELEASE="CI-$(date +"%Y%m%d")"
fi

KERNEL_DEFCONFIG="gki_defconfig"
SUSFS_BRANCH="gki-android12-5.10"

sudo timedatectl set-timezone "$TIMEZONE" || export TZ="$TIMEZONE"

# Telegram Functions
tg_send_msg() {
    if [ -n "$TG_BOT_TOKEN" ] && [ -n "$TG_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
            -d chat_id="${TG_CHAT_ID}" \
            -d parse_mode="HTML" \
            -d text="$1" >/dev/null
    fi
}
tg_send_doc() {
    if [ -n "$TG_BOT_TOKEN" ] && [ -n "$TG_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendDocument" \
            -F chat_id="${TG_CHAT_ID}" \
            -F document="@$1" \
            -F caption="$2" \
            -F parse_mode="HTML" >/dev/null
    fi
}

echo "-> Downloading and setting up Clang..."
CLANG_DIR="$WORKDIR/clang"
if [ ! -d "$CLANG_DIR" ]; then
    wget -qO clang_archive "$CLANG_URL"
    mkdir -p "$CLANG_DIR"
    if [[ "$CLANG_URL" == *".tar.zst" ]]; then
        tar -I zstd -xf clang_archive -C "$CLANG_DIR"
    elif [[ "$CLANG_URL" == *".tgz" ]] || [[ "$CLANG_URL" == *".tar.gz" ]]; then
        tar -xf clang_archive -C "$CLANG_DIR"
    fi
    rm -f clang_archive
fi
export PATH="${CLANG_DIR}/bin:$PATH"
COMPILER_STRING=$(clang --version | head -n 1 | sed 's/(https..*//' | sed 's/ version//')

echo "-> Cloning Kernel Source..."
if [ ! -d "$KSRC" ]; then
    git clone --depth=1 -b "$KERNEL_BRANCH" "$KERNEL_SOURCE" "$KSRC"
fi

cd "$KSRC"
LINUX_VERSION=$(make kernelversion)
LINUX_VERSION_CODE=${LINUX_VERSION//./}
k_lastcommit=$(git rev-parse --short HEAD)

rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"

# KSUN and SUSFS
if [ "$VARIANT" == "KSUN_SUSFS" ]; then
    echo "-> Setting up KernelSU-Next and SUSFS..."
    # Remove existing KSUN
    for KSUN_PATH in drivers/staging/kernelsu drivers/kernelsu KernelSU KernelSU-Next; do
        if [[ -d $KSUN_PATH ]]; then
            echo "Removing existing $KSUN_PATH"
            KSUN_DIR=$(dirname "$KSUN_PATH")
            [[ -f "$KSUN_DIR/Kconfig" ]] && sed -i '/kernelsu/d' "$KSUN_DIR/Kconfig"
            [[ -f "$KSUN_DIR/Makefile" ]] && sed -i '/kernelsu/d' "$KSUN_DIR/Makefile"
            rm -rf $KSUN_PATH
        fi
    done

    # KernelSU-Next
    curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/refs/heads/dev-susfs/kernel/setup.sh" | bash -s dev-susfs

    # SUSFS
    SUSFS_DIR="$WORKDIR/susfs"
    if [ ! -d "$SUSFS_DIR" ]; then
        git clone --depth=1 -q https://gitlab.com/simonpunk/susfs4ksu -b "$SUSFS_BRANCH" "$SUSFS_DIR"
    fi

    SUSFS_PATCHES="${SUSFS_DIR}/kernel_patches"
    cp -R "$SUSFS_PATCHES"/fs/* ./fs/
    cp -R "$SUSFS_PATCHES"/include/* ./include/

    patch -p1 < "$SUSFS_PATCHES/50_add_susfs_in_${SUSFS_BRANCH}.patch" || true
    
    # Apply extra KSUN and SUSFS configs
    cat << EOF >> arch/arm64/configs/$KERNEL_DEFCONFIG
# Extras
CONFIG_OVERLAY_FS_XINO_AUTO=y
CONFIG_KALLSYMS=y
CONFIG_TMPFS_POSIX_ACL=y
# KSU
CONFIG_KSU=y
CONFIG_KSU_MANUAL_HOOK=y
# SUSFS
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_TRY_UMOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
EOF
    ./scripts/config --file arch/arm64/configs/$KERNEL_DEFCONFIG --disable CONFIG_KSU_SUSFS_SUS_SU

    SUSFS_VERSION=$(grep -E '^#define SUSFS_VERSION' ./include/linux/susfs.h | cut -d' ' -f3 | sed 's/"//g')
else
    # Vanilla config
    SUSFS_VERSION="None"
fi

# Set Localversion
./scripts/config --file arch/arm64/configs/$KERNEL_DEFCONFIG --set-str CONFIG_LOCALVERSION "-$KERNEL_NAME/$RELEASE"
./scripts/config --file arch/arm64/configs/$KERNEL_DEFCONFIG --disable CONFIG_LOCALVERSION_AUTO
sed -i 's/echo "+"/# echo "+"/g' scripts/setlocalversion

# Build Variables
export KBUILD_BUILD_USER="$KBUILD_USER"
export KBUILD_BUILD_HOST="$KBUILD_HOST"
export KBUILD_BUILD_TIMESTAMP=$(date)
export KCFLAGS="-w"

MAKE_ARGS=(
  O=$OUTDIR
  ARCH=arm64
  LLVM=1
  LLVM_IAS=1
  CROSS_COMPILE=aarch64-linux-gnu-
  CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
  CC=clang
)

echo "-> Building Kernel..."
tg_send_msg "🚀 <b>Build Started</b>%0A<b>Kernel:</b> <code>${LINUX_VERSION}</code>%0A<b>Variant:</b> <code>${VARIANT}</code>%0A<b>Build Type:</b> <code>${RELEASE_TYPE}</code>"

make "${MAKE_ARGS[@]}" $KERNEL_DEFCONFIG
make -j$(nproc --all) "${MAKE_ARGS[@]}"

KERNEL_IMAGE="$OUTDIR/arch/arm64/boot/Image"
if [ ! -f "$KERNEL_IMAGE" ]; then
    echo "-> Build Failed!"
    tg_send_msg "❌ <b>Build Failed!</b>%0A<b>Variant:</b> <code>${VARIANT}</code>"
    exit 1
fi

tg_send_msg "✅ <b>Build Successful!</b>%0A<b>Variant:</b> <code>${VARIANT}</code>"

# AnyKernel Packaging
cd "$WORKDIR"
if [ ! -d "AnyKernel3" ]; then
    git clone --depth=1 -b "$ANYKERNEL_BRANCH" "$ANYKERNEL_REPO" AnyKernel3
fi

AK3_ZIP_NAME="${KERNEL_NAME}-${RELEASE}-${LINUX_VERSION}-${VARIANT}.zip"
sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME} ${RELEASE} ${LINUX_VERSION} ${VARIANT}/g" AnyKernel3/anykernel.sh
sed -i "s/supported_kver=.*/supported_kver='5.10'/g" AnyKernel3/anykernel.sh

rm -f AnyKernel3/Image AnyKernel3/Image.gz AnyKernel3/Image-dtb AnyKernel3/dtb AnyKernel3/*.zip
cp "$KERNEL_IMAGE" AnyKernel3/

cd AnyKernel3
zip -r9 "../${AK3_ZIP_NAME}" * -x .git README.md *placeholder
cd ..

# Release
if [ "$RELEASE_TYPE" == "Release" ] && command -v gh &> /dev/null && [ -n "$GITHUB_TOKEN" ]; then
    gh release create "${AK3_ZIP_NAME%.*}" "${AK3_ZIP_NAME}" \
        --repo "$RELEASE_REPO" \
        --title "Kernel Release ${AK3_ZIP_NAME%.*}" \
        --notes "Automated GKI Kernel Release%0A**Variant:** ${VARIANT}"
fi

# Set proper caption based on Build Type
if [ "$RELEASE_TYPE" == "Release" ]; then
  HEADER="📦 <b>New Kernel Release!</b>"
else
  HEADER="🧪 <b>New CI Build!</b>"
fi

MSG=$(cat << EOF
${HEADER}%0A
<b>Version:</b> <code>${LINUX_VERSION}</code>%0A
<b>Variant:</b> <code>${VARIANT}</code>%0A
<b>SuSFS:</b> <code>${SUSFS_VERSION}</code>%0A
<b>Compiler:</b> <code>${COMPILER_STRING}</code>
EOF
)

tg_send_doc "${AK3_ZIP_NAME}" "$MSG"
echo "-> All tasks completed successfully!"

#!/bin/bash
set -e

DEVICE="lisa"
VENDOR="xiaomi"

KERNEL_REPO="https://github.com/pisti87/android_kernel_xiaomi_lisa.git"
KERNEL_BRANCH="halium"

WORKDIR="$HOME/droidian-$DEVICE"
KERNEL_DIR="$WORKDIR/kernel"
PACKAGES_DIR="$WORKDIR/packages"

mkdir -p "$WORKDIR"

echo "[0/7] Checking dependencies..."
sudo apt update
sudo apt install -y docker.io git

echo "[1/7] Cloning kernel..."
mkdir -p "$KERNEL_DIR"
git clone --depth=1 -b "$KERNEL_BRANCH" "$KERNEL_REPO" "$KERNEL_DIR"

cd "$KERNEL_DIR"
git checkout -b droidian || true

echo "[2/7] Starting Droidian build container..."

mkdir -p "$PACKAGES_DIR"

docker run --rm -it \
  -v "$KERNEL_DIR:/buildd/sources" \
  -v "$PACKAGES_DIR:/buildd" \
  quay.io/droidian/build-essential:trixie-amd64 bash <<'EOF'

set -e

cd /buildd/sources

echo "[inside] Installing packaging tools..."
apt update
apt install -y linux-packaging-snippets

echo "[inside] Creating Debian packaging skeleton..."
mkdir -p debian/source

cp /usr/share/linux-packaging-snippets/kernel-info.mk.example debian/kernel-info.mk

echo "3.0 (native)" > debian/source/format
echo 13 > debian/compat

cat > debian/rules <<RULES
#!/usr/bin/make -f
include /usr/share/linux-packaging-snippets/kernel-snippet.mk

%:
	dh $@
RULES

chmod +x debian/rules

echo "[inside] Setting kernel-info.mk..."

cat >> debian/kernel-info.mk <<MK

KERNEL_ARCH := arm64
DEB_BUILD_FOR := arm64

KERNEL_DEFCONFIG := lisa_defconfig
KERNEL_BASE_VERSION := 5.4.0

BUILD_CC := clang

KERNEL_CMDLINE := console=tty0 droidian.lvm.prefer

KERNEL_BOOTIMAGE_PAGE_SIZE := 4096
KERNEL_BOOTIMAGE_BASE_OFFSET := 0x40000000
KERNEL_BOOTIMAGE_KERNEL_OFFSET := 0x00008000
KERNEL_BOOTIMAGE_INITRAMFS_OFFSET := 0x01000000
KERNEL_BOOTIMAGE_TAGS_OFFSET := 0x00000100
KERNEL_BOOTIMAGE_VERSION := 2

FLASH_ENABLED := 1
FLASH_IS_LEGACY_DEVICE := 0

MK

echo "[inside] Preparing control file..."
dh debian/control

echo "[inside] Building kernel..."
export RELENG_HOST_ARCH=arm64
releng-build-package

EOF

echo "[7/7] DONE"
echo "Packages available in: $PACKAGES_DIR"

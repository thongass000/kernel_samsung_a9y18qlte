#!/bin/bash

# Riaru Kernel Simple Build System
# Here is the dependencies to build the kernel
# Ubuntu/Ubuntu Based OS: apt update && apt upgrade && apt install glibc-source libghc-libyaml-dev libyaml-dev binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi binutils device-tree-compiler libtfm-dev libelf-dev cpio kmod nano bc bison ca-certificates curl flex gcc git libc6-dev libssl-dev openssl python-is-python3 ssh wget zip zstd sudo make clang gcc-arm-linux-gnueabi software-properties-common build-essential libarchive-tools gcc-aarch64-linux-gnu python2
# Arch/Arch Based OS: sudo pacman -S aarch64-linux-gnu-glibc glibc libyaml aarch64-linux-gnu-binutils arm-none-eabi-binutils binutils dtc fmt libelf cpio kmod bc bison ca-certificates curl flex glibc openssl openssh wget zip zstd make clang aarch64-linux-gnu-gcc arm-none-eabi-gcc archivetools base-devel python git
# Fedora/Fedora Based OS: sudo dnf install glibc libyaml binutils dtc fmt cpio kmod bc bison ca-certificates curl flex openssl openssl-devel openssl-devel-engine openssh wget zip zstd make clang python git arm-none-eabi-gcc-cs gcc-aarch64-linux-gnu arm-none-eabi-binutils-cs binutils-aarch64-linux-gnu cross-binutils-common cross-gcc-common gmp-c++ gmp-devel isl libmpc-devel mpfr-devel

# Logs
echo "Removing previous kernel build logs..."
LOGGER=build_kernel.log
REALLOGGER="$(pwd)"/${LOGGER}
rm -rf $REALLOGGER

# Manual clock sync for WSL, look at your /usr/share/zoneinfo/* to see more info
ISTHISWSL=0
CONTINENTS=Asia
LOCATION=Makassar
if [ "$ISTHISWSL" == "1" ]; then
	echo "Asking sudo password for updating the timezone manually..."
	sudo ln -sf /usr/share/zoneinfo/$CONTINENTS/$LOCATION /etc/localtime &>> $REALLOGGER
	sudo hwclock --systohc &>> $REALLOGGER
fi

# LineageOS 19.1 Google GCC 4.9
NOTHAVEGCC=1
LOSGCC_DIR="los-gcc"
REALLOSGCC_DIR="$(pwd)"/${LOSGCC_DIR}
if [ "$NOTHAVEGCC" == "1" ]; then
	echo "Cloning Google GCC 4.9 from LienageOS Repository..."
	git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 $LOSGCC_DIR &>> $REALLOGGER
fi
echo "Setting up proper permissions to GCC and export it to PATH..."
sudo chmod 755 -R $REALLOSGCC_DIR &>> $REALLOGGER
export PATH="$REALLOSGCC_DIR/bin:$PATH"

# Variables
export KBUILD_BUILD_USER="$USER"
export KBUILD_BUILD_HOST="$HOSTNAME"
export CROSS_COMPILE=aarch64-linux-android-
export ARCH=arm64
export SUBARCH=arm64
export HEADER_ARCH=arm64
DEFCONFIG=a9y18qlte_eur_open_defconfig

# KernelSU Support
KSU=$1
if [ "$KSU" == "--ksu" ]; then
	echo "KernelSU support is enabled, downloading KernelSU..."
	rm -rf KernelSU &>> $REALLOGGER
	cd drivers
	rm -rf kernelsu &>> $REALLOGGER
	cd ..
	git clone https://github.com/rifsxd/KernelSU-Next KernelSU &>> $REALLOGGER
	cd drivers
	ln -sf ../KernelSU/kernel kernelsu &>> $REALLOGGER
	cd ..
	sed -i '/source "drivers\/security\/samsung\/icdrv\/Kconfig"/a source "drivers\/kernelsu\/Kconfig"' drivers/Kconfig
	sed -i 's/# CONFIG_KSU is not set/CONFIG_KSU=y/' arch/arm64/configs/$DEFCONFIG
	sed -i 's/# CONFIG_KSU_DEBUG is not set/CONFIG_KSU_DEBUG=y/' arch/arm64/configs/$DEFCONFIG
else
	echo "KernelSU support is disabled, skipping..."
	rm -rf KernelSU &>> $REALLOGGER
	cd drivers
	rm -rf kernelsu &>> $REALLOGGER
	cd ..
	sed -i '/source "drivers\/kernelsu\/Kconfig"/d' drivers/Kconfig
fi

# Cleanup
echo "Cleaning up out directory..."
rm -rf out
mkdir out
rm -rf error.log

# Compile
CPUCORE=$(nproc --all)
echo "Compiling the kernel..."
make -j$CPUCORE O=out clean &>> $REALLOGGER
make -j$CPUCORE O=out $DEFCONFIG &>> $REALLOGGER
make -j$CPUCORE ARCH=arm64 O=out SUBARCH=arm64 O=out \
        CC=${REALLOSGCC_DIR}/bin/aarch64-linux-android-gcc \
        LD=${REALLOSGCC_DIR}/bin/aarch64-linux-android-ld.bfd \
        AR=${REALLOSGCC_DIR}/bin/aarch64-linux-android-ar \
        AS=${REALLOSGCC_DIR}/bin/aarch64-linux-android-as \
        NM=${REALLOSGCC_DIR}/bin/aarch64-linux-android-nm \
        OBJCOPY=${REALLOSGCC_DIR}/bin/aarch64-linux-android-objcopy \
        OBJDUMP=${REALLOSGCC_DIR}/bin/aarch64-linux-android-objdump \
        STRIP=${REALLOSGCC_DIR}/bin/aarch64-linux-android-strip \
        CROSS_COMPILE=${REALLOSGCC_DIR}/bin/aarch64-linux-android- &>> $REALLOGGER

# Copy logs to out
echo "Copying logs to out directory..."
cp $REALLOGGER out/arch/arm64/boot
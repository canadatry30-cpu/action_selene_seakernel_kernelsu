#!/bin/bash

# 设置工作目录
WORKDIR="$(pwd)"

# ZyClang 工具链下载链接
ZYCLANG_DLINK="https://github.com/ZyCromerZ/Clang/releases/download/19.0.0git-20240217-release/Clang-19.0.0git-20240217.tar.gz"

# 默认设置
export TZ=Asia/Shanghai

# 打印信息函数
msg() {
    echo -e "\e[1;32m$1\e[0m"
}

# 准备工具链
msg " • 🚀 Downloading ZyClang 🚀 "
mkdir -p $WORKDIR/ZyClang
wget -q $ZYCLANG_DLINK -O clang.tar.gz
tar -xzf clang.tar.gz -C $WORKDIR/ZyClang
rm -rf clang.tar.gz

# 设置环境变量
export PATH="$WORKDIR/ZyClang/bin:$PATH"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_COMPILER_STRING="$($WORKDIR/ZyClang/bin/clang --version | head -n 1)"

# 克隆内核源码
msg " • 🌿 Cloning Kernel Source 🌿 "
# 假设源码已经通过 GitHub Actions 检出到 $WORKDIR/Kernel 目录
cd $WORKDIR/Kernel

# 强制开启 Droidspaces 所需的 IPC 命名空间支持
msg " • 🛠️ Injecting Droidspaces IPC Patch 🛠️ "
echo "CONFIG_IPC_NS=y" >> arch/arm64/configs/selene_defconfig
echo "CONFIG_SYSVIPC=y" >> arch/arm64/configs/selene_defconfig
echo "CONFIG_SYSVIPC_SYSCTL=y" >> arch/arm64/configs/selene_defconfig
echo "CONFIG_POSIX_MQUEUE=y" >> arch/arm64/configs/selene_defconfig

# 开始编译
msg " • 🔨 Building Kernel 🔨 "
make O=out selene_defconfig
make -j$(nproc --all) O=out \
    CC=clang \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-

# 检查编译结果
if [ -f "out/arch/arm64/boot/Image.gz-dtb" ]; then
    msg " • 🎉 Kernel compiled successfully! 🎉 "
else
    echo "ERROR: Kernel compilation failed!"
    exit 1
fi

# 打包内核
msg " • 🌸 Packing Kernel 🌸 "
cd $WORKDIR

# 强制在这里硬编码声明打包变量，防止丢失
ANYKERNEL3_GIT="https://github.com/osm0sis/AnyKernel3.git"
ANYKERNEL3_BRANCHE="master"

# 克隆 Anykernel3
git clone --depth=1 $ANYKERNEL3_GIT -b $ANYKERNEL3_BRANCHE $WORKDIR/Anykernel3

# 复制编译好的内核文件到打包目录
cd $WORKDIR/Anykernel3
cp $WORKDIR/Kernel/out/arch/arm64/boot/Image.gz-dtb .
if [ -f "$WORKDIR/Kernel/out/arch/arm64/boot/dtb" ]; then
    cp $WORKDIR/Kernel/out/arch/arm64/boot/dtb .
fi
if [ -f "$WORKDIR/Kernel/out/arch/arm64/boot/dtbo.img" ]; then
    cp $WORKDIR/Kernel/out/arch/arm64/boot/dtbo.img .
fi

# 调整 AnyKernel3 配置文件
sed -i 's/do.devicecheck=1/do.devicecheck=0/g' anykernel.sh

# 生成压缩包并防范无限文件夹循环
ZIP_NAME="SeaKernel-Selene-IPC-Custom"
msg " • 📦 Creating Flashable Zip 📦 "
zip -r9 $ZIP_NAME.zip . -x "Kernel/*" -x "*/Kernel/*" -x "ZyClang/*" -x "out/*" -x "*.git*"

# 移动到输出目录供 GitHub Actions 上传
mkdir -p $WORKDIR/output
mv $ZIP_NAME.zip $WORKDIR/output/
msg " • ✅ Done! Your zip file is waiting in the output folder. ✅ "

cd ~/
sudo apt install git bc bison flex libssl-dev make libc6-dev libncurses5-dev -y
sudo apt install crossbuild-essential-arm64 -y
git clone --depth=1 https://github.com/raspberrypi/linux
git clone https://github.com/kipr/wombat-os
cd linux
KERNEL=kernel8

echo "#In menuconfig --> Device drivers --> Input device support --> Touchscreens \n \
# Go to TSC2007 based touchscreens and press M \n \
# Save to .config \n \
# Exit all the way out (4 times) \n"
echo "Press any key to continue..."
read -n 1 -s

make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2711_defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- menuconfig
sed -i 's/# CONFIG_TOUCHSCREEN_TSC2007 is not set/CONFIG_TOUCHSCREEN_TSC2007=m/' .config

sudo cp ~/wombat-os/kernelFiles/tsc2007.dts ~/linux/arch/arm64/boot/dts/overlays/tsc2007.dts
sudo cp ~/wombat-os/kernelFiles/Makefile ~/linux/arch/arm64/boot/dts/overlays/Makefile
lsblk
mkdir mnt && mkdir mnt/boot && mkdir mnt/root
mkdir mnt/boot
mkdir mnt/root
sudo mount /dev/sda1 mnt/boot     # Check your mount directory to see which version of sd* it is.
sudo mount /dev/sda2 mnt/root
sudo cp ~/wombat-os/kernelFiles/config.txt ~/linux/mnt/boot/config.txt
sudo chmod 777 mnt/root/etc/modules
sudo echo 'tsc2007' >> mnt/root/etc/modules
sudo env PATH=$PATH make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- INSTALL_MOD_PATH=mnt/root modules_install
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image modules dtbs
sudo cp mnt/boot/$KERNEL.img mnt/boot/$KERNEL-backup.img
sudo cp arch/arm64/boot/Image mnt/boot/$KERNEL.img
sudo cp arch/arm64/boot/dts/broadcom/*.dtb mnt/boot/
sudo cp arch/arm64/boot/dts/overlays/*.dtb* mnt/boot/overlays/
sudo cp arch/arm/boot/dts/overlays/README mnt/boot/overlays/
sudo umount mnt/boot
sudo umount mnt/root

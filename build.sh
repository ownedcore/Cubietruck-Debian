#!/bin/bash

# --- Configuration -------------------------------------------------------------
VERSION="CTDebian 1.6"
SOURCE_COMPILE="yes"
DEST_LANG="en_US"
DEST_LANGUAGE="en"
DEST=/tmp/Cubie
DISPLAY=3  # "0:none; 1:lcd; 2:tv; 3:hdmi; 4:vga"
DISPNAME="hdmi"
# --- End -----------------------------------------------------------------------
# --- Options --------------------------------------------------------------------
while getopts d: flag; do
        case $flag in
                d)      DISPNAME=$OPTARG
                        case $OPTARG in
                                none)   DISPLAY=0;;
                                lcd)    DISPLAY=1;;
                                tv)     DISPLAY=2;;
                                hdmi)   DISPLAY=3;;
                                vga)    DISPLAY=4;;
                                *)      echo "Use one of none | lcd | tv | hdmi | vga"
                                        exit 0;;
                        esac
                        ;;
                ?)
                        #echo "Unkown option given"
                        exit 1;;
        esac
done
shift $((OPTIND-1))
# --- Options End ----------------------------------------------------------------
SRC=$(pwd)
set -e

#Requires root ..
if [ "$UID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
echo "Building Cubietruck-Debian in $DEST from $SRC"
sleep 3
#--------------------------------------------------------------------------------
# Downloading necessary files
#--------------------------------------------------------------------------------
echo "------ Downloading necessary files"
apt-get -qq -y install binfmt-support bison build-essential ccache debootstrap flex gawk gcc-arm-linux-gnueabi gcc-arm-linux-gnueabihf gettext linux-headers-generic linux-image-generic lvm2 qemu-user-static texinfo texlive u-boot-tools uuid-dev zlib1g-dev unzip libncurses5-dev pkg-config libusb-1.0-0-dev parted

#--------------------------------------------------------------------------------
# Preparing output / destination files
#--------------------------------------------------------------------------------

echo "------ Fetching files from github"
mkdir -p $DEST/output
cp output/uEnv.* $DEST/output

if [ -d "$DEST/u-boot-sunxi" ]
then
	cd $DEST/u-boot-sunxi ; git pull; cd $SRC
else
	#git clone https://github.com/cubieboard/u-boot-sunxi $DEST/u-boot-sunxi # Boot loader
	git clone https://github.com/patrickhwood/u-boot -b pat-cb2-ct  $DEST/u-boot-sunxi # CB2 / CT Dual boot loader
fi
if [ -d "$DEST/sunxi-tools" ]
then
	cd $DEST/sunxi-tools; git pull; cd $SRC
else
	git clone https://github.com/linux-sunxi/sunxi-tools.git $DEST/sunxi-tools # Allwinner tools
fi
if [ -d "$DEST/cubie_configs" ]
then
	cd $DEST/cubie_configs; git pull; cd $SRC
else
	git clone https://github.com/cubieboard/cubie_configs $DEST/cubie_configs # Hardware configurations
fi
if [ -d "$DEST/linux-sunxi" ]
then
	cd $DEST/linux-sunxi; git pull -f; cd $SRC
else
	# git clone https://github.com/cubieboard/linux-sunxi/ $DEST/linux-sunxi # Kernel 3.4.61+
	git clone https://github.com/patrickhwood/linux-sunxi $DEST/linux-sunxi # Patwood's kernel 3.4.75+
fi

# Applying Patch for 2gb memory
# patch -f $DEST/u-boot-sunxi/include/configs/sunxi-common.h < $SRC/patch/memory.patch || true

# Applying Patch for gpio
#patch -f $DEST/linux-sunxi/drivers/gpio/gpio-sunxi.c < $SRC/patch/gpio.patch || true

# Applying Patch for high load. Could cause troubles with USB OTG port
# ??? Check for DISPLAY START ???
#sed -e 's/usb_detect_type     = 1/usb_detect_type     = 0/g' $DEST/cubie_configs/sysconfig/linux/cubietruck.fex > $DEST/cubie_configs/sysconfig/linux/ct.fex
# Change Video output ( TODO add a param so the user can choose that ?)
#sed -e 's/screen0_output_type.*/screen0_output_type     = '$DISPLAY'/g' $DEST/cubie_configs/sysconfig/linux/cubietruck.fex > $DEST/cubie_configs/sysconfig/linux/ct-${DISPNAME}.fex
# ??? Check for DISPLAY END ???

sed -e 's/usb_detect_type     = 1/usb_detect_type     = 0/g' -i $DEST/cubie_configs/sysconfig/linux/cubietruck.fex 
sed -e 's/usb_detect_type     = 1/usb_detect_type     = 0/g' -i $DEST/cubie_configs/sysconfig/linux/cubieboard2.fex

# Prepare fex files for VGA & HDMI
sed -e 's/screen0_output_type.*/screen0_output_type     = 3/g' $DEST/cubie_configs/sysconfig/linux/cubietruck.fex > $DEST/cubie_configs/sysconfig/linux/ct-hdmi.fex
sed -e 's/screen0_output_type.*/screen0_output_type     = 4/g' $DEST/cubie_configs/sysconfig/linux/cubietruck.fex > $DEST/cubie_configs/sysconfig/linux/ct-vga.fex
sed -e 's/screen0_output_type.*/screen0_output_type     = 3/g' $DEST/cubie_configs/sysconfig/linux/cubieboard2.fex > $DEST/cubie_configs/sysconfig/linux/cb2-hdmi.fex
sed -e 's/screen0_output_type.*/screen0_output_type     = 4/g' $DEST/cubie_configs/sysconfig/linux/cubieboard2.fex > $DEST/cubie_configs/sysconfig/linux/cb2-vga.fex

# Copying Kernel config
cp $SRC/config/kernel.config $DEST/linux-sunxi/

#--------------------------------------------------------------------------------
# Compiling everything
#--------------------------------------------------------------------------------
echo "------ Compiling kernel boot loaderb"
cd $DEST/u-boot-sunxi
# boot loader
make clean && make -j2 'cubietruck' CROSS_COMPILE=arm-linux-gnueabihf-
echo "------ Compiling sunxi tools"
cd $DEST/sunxi-tools
# sunxi-tools
make clean && make fex2bin && make bin2fex
cp fex2bin bin2fex /usr/local/bin/
# hardware configuration
# ??? Check for DISPLAY START ???
#fex2bin $DEST/cubie_configs/sysconfig/linux/ct-${DISPNAME}.fex $DEST/output/script.bin
#fex2bin $DEST/cubie_configs/sysconfig/linux/ct.fex $DEST/output/script-hdmi.bin
# ??? Check for DISPLAY END ???

fex2bin $DEST/cubie_configs/sysconfig/linux/ct-vga.fex $DEST/output/ct-vga.bin
fex2bin $DEST/cubie_configs/sysconfig/linux/ct-hdmi.fex $DEST/output/ct-hdmi.bin
fex2bin $DEST/cubie_configs/sysconfig/linux/cb2-hdmi.fex $DEST/output/cb2-hdmi.bin
fex2bin $DEST/cubie_configs/sysconfig/linux/cb2-vga.fex $DEST/output/cb2-vga.bin
if [ "$SOURCE_COMPILE" = "yes" ]; then
# kernel image
echo "------ Compiling kernel"
cd $DEST/linux-sunxi
make clean

# Adding wlan firmware to kernel source
cd $DEST/linux-sunxi/firmware; 
unzip -o $SRC/bin/ap6210.zip
cd $DEST/linux-sunxi

make -j2 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- sun7i_defconfig
# get proven config
cp $DEST/linux-sunxi/kernel.config $DEST/linux-sunxi/.config
make -j2 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- uImage modules
make -j2 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=output modules_install
make -j2 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_HDR_PATH=output headers_install
fi

#--------------------------------------------------------------------------------
# Creating SD Images
#--------------------------------------------------------------------------------
echo "------ Creating SD Images"
cd $DEST/output
# create 1Gb image and mount image to next free loop device
dd if=/dev/zero of=debian_rootfs.raw bs=1M count=1000
LOOP=$(losetup -f)
losetup $LOOP debian_rootfs.raw

echo "------ Partitionning and mounting filesystem"
# make image bootable
dd if=$DEST/u-boot-sunxi/u-boot-sunxi-with-spl.bin of=$LOOP bs=1024 seek=8

# create one partition starting at 2048 which is default
(echo n; echo p; echo 1; echo; echo; echo w) | fdisk $LOOP >> /dev/null || true
# just to make sure
partprobe $LOOP
losetup -d $LOOP

# 2048 (start) x 512 (block size) = where to mount partition
losetup -o 1048576 $LOOP debian_rootfs.raw
# create filesystem
mkfs.ext4 $LOOP
# create mount point and mount image 
mkdir -p $DEST/output/sdcard/
mount $LOOP $DEST/output/sdcard/
mount

echo "------ Install basic filesystem"
# install base system
debootstrap --no-check-gpg --arch=armhf --foreign wheezy $DEST/output/sdcard/
# we need this
cp /usr/bin/qemu-arm-static $DEST/output/sdcard/usr/bin/
# enable arm binary format so that the cross-architecture chroot environment will work
test -e /proc/sys/fs/binfmt_misc/qemu-arm || update-binfmts --enable qemu-arm
# mount proc inside chroot
mount -t proc chproc $DEST/output/sdcard/proc
# second stage unmounts proc 
chroot $DEST/output/sdcard /bin/bash -c "/debootstrap/debootstrap --second-stage"
# mount proc, sys and dev
mount -t proc chproc $DEST/output/sdcard/proc
mount -t sysfs chsys $DEST/output/sdcard/sys
# This works on half the systems I tried.  Else use bind option
mount -t devtmpfs chdev $DEST/output/sdcard/dev || mount --bind /dev $DEST/output/sdcard/dev
mount -t devpts chpts $DEST/output/sdcard/dev/pts

# update /etc/issue
cat <<EOT > $DEST/output/sdcard/etc/issue
Debian GNU/Linux 7 $VERSION

EOT

# update /etc/motd
cat > $DEST/output/sdcard/etc/motd <<EOF
              _      _        _                       _    
  ___  _   _ | |__  (_)  ___ | |_  _ __  _   _   ___ | | __
 / __|| | | || '_ \ | | / _ \| __|| '__|| | | | / __|| |/ /
| (__ | |_| || |_) || ||  __/| |_ | |   | |_| || (__ |   < 
 \___| \__,_||_.__/ |_| \___| \__||_|    \__,_| \___||_|\_\
                                                          

EOF


# apt list
cat <<EOT > $DEST/output/sdcard/etc/apt/sources.list
deb http://http.debian.net/debian wheezy main contrib non-free
deb-src http://http.debian.net/debian wheezy main contrib non-free
deb http://http.debian.net/debian wheezy-updates main contrib non-free
deb-src http://http.debian.net/debian wheezy-updates main contrib non-free
deb http://security.debian.org/debian-security wheezy/updates main contrib non-free
deb-src http://security.debian.org/debian-security wheezy/updates main contrib non-free
EOT

# update
chroot $DEST/output/sdcard /bin/bash -c "apt-get update"
chroot $DEST/output/sdcard /bin/bash -c "export LANG=C"    

# set up 'apt
cat <<END > $DEST/output/sdcard/etc/apt/apt.conf.d/71-no-recommends
APT::Install-Recommends "0";
APT::Install-Suggests "0";
END

# script to turn off the LED blinking
cp $SRC/scripts/disable_led.sh $DEST/output/sdcard/etc/init.d/disable_led.sh

# make it executable
chroot $DEST/output/sdcard /bin/bash -c "chmod +x /etc/init.d/disable_led.sh"
# and startable on boot
chroot $DEST/output/sdcard /bin/bash -c "update-rc.d disable_led.sh defaults" 

# scripts for autoresize at first boot from cubian
cd $DEST/output/sdcard/etc/init.d
cp $SRC/scripts/cubian-resize2fs $DEST/output/sdcard/etc/init.d
cp $SRC/scripts/cubian-firstrun $DEST/output/sdcard/etc/init.d

# script to install to NAND
cp $SRC/scripts/nand-install.sh $DEST/output/sdcard/root
cp $SRC/bin/nand1-cubietruck-debian-boot.tgz $DEST/output/sdcard/root

# make it executable
chroot $DEST/output/sdcard /bin/bash -c "chmod +x /etc/init.d/cubian-*"
# and startable on boot
chroot $DEST/output/sdcard /bin/bash -c "update-rc.d cubian-firstrun defaults" 
# install and configure locales
chroot $DEST/output/sdcard /bin/bash -c "apt-get -qq -y install locales"
# reconfigure locales
echo -e $DEST_LANG'.UTF-8 UTF-8\n' > $DEST/output/sdcard/etc/locale.gen 
chroot $DEST/output/sdcard /bin/bash -c "locale-gen"
echo -e 'LANG="'$DEST_LANG'.UTF-8"\nLANGUAGE="'$DEST_LANG':'$DEST_LANGUAGE'"\n' > $DEST/output/sdcard/etc/default/locale
chroot $DEST/output/sdcard /bin/bash -c "export LANG=$DEST_LANG.UTF-8"
chroot $DEST/output/sdcard /bin/bash -c "apt-get -qq -y install libfuse2 ntfs-3g bash-completion lsof console-data sudo git hostapd dosfstools htop openssh-server ca-certificates module-init-tools dhcp3-client udev ifupdown iproute iputils-ping ntpdate ntp rsync usbutils uboot-envtools pciutils wireless-tools wpasupplicant procps libnl-dev parted cpufrequtils console-setup unzip bridge-utils" 
chroot $DEST/output/sdcard /bin/bash -c "apt-get -qq -y upgrade"

# configure MIN / MAX Speed for cpufrequtils
sed -e 's/MIN_SPEED="0"/MIN_SPEED="480000"/g' -i $DEST/output/sdcard/etc/init.d/cpufrequtils
sed -e 's/MAX_SPEED="0"/MAX_SPEED="1010000"/g' -i $DEST/output/sdcard/etc/init.d/cpufrequtils
sed -e 's/ondemand/interactive/g' -i $DEST/output/sdcard/etc/init.d/cpufrequtils

# set password to 1234
chroot $DEST/output/sdcard /bin/bash -c "(echo 1234;echo 1234;) | passwd root" 

# set hostname 
echo cubie > $DEST/output/sdcard/etc/hostname

# load modules
cat <<EOT >> $DEST/output/sdcard/etc/modules
hci_uart
gpio_sunxi
bcmdhd
# if you want access point mode, load wifi module this way: bcmdhd op_mode=2
EOT

# create interfaces configuration
cat <<EOT >> $DEST/output/sdcard/etc/network/interfaces
auto eth0
allow-hotplug eth0
iface eth0 inet dhcp
        hwaddress ether # will be added at first boot
#        pre-up /sbin/ifconfig eth0 mtu 3838 # setting MTU for DHCP, static just: mtu 3838
#auto wlan0
#allow-hotplug wlan0
#iface wlan0 inet dhcp
#    wpa-ssid SSID 
#    wpa-psk xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# to generate proper encrypted key: wpa_passphrase yourSSID yourpassword
EOT


# create interfaces if you want to have AP. /etc/modules must be: bcmdhd op_mode=2
cat <<EOT >> $DEST/output/sdcard/etc/network/interfaces.hostapd
auto lo br0
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet manual

allow-hotplug wlan0
iface wlan0 inet manual

iface br0 inet dhcp
bridge_ports eth0 wlan0
hwaddress ether # will be added at first boot
EOT

# enable serial console (Debian/sysvinit way)
echo T0:2345:respawn:/sbin/getty -L ttyS0 115200 vt100 >> $DEST/output/sdcard/etc/inittab

cp $DEST/output/uEnv.* $DEST/output/sdcard/boot/
cp $DEST/output/*.bin $DEST/output/sdcard/boot/
cp $DEST/linux-sunxi/arch/arm/boot/uImage $DEST/output/sdcard/boot/
cp -R $DEST/linux-sunxi/output/lib/modules $DEST/output/sdcard/lib/
cp -R $DEST/linux-sunxi/output/lib/firmware/ $DEST/output/sdcard/lib/

# USB redirector tools http://www.incentivespro.com
cd $DEST
wget http://www.incentivespro.com/usb-redirector-linux-arm-eabi.tar.gz
tar xvfz usb-redirector-linux-arm-eabi.tar.gz
rm usb-redirector-linux-arm-eabi.tar.gz
cd $DEST/usb-redirector-linux-arm-eabi/files/modules/src/tusbd
make -j2 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KERNELDIR=$DEST/linux-sunxi/
# configure USB redirector
sed -e 's/%INSTALLDIR_TAG%/\/usr\/local/g' $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd > $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd1
sed -e 's/%PIDFILE_TAG%/\/var\/run\/usbsrvd.pid/g' $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd1 > $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd
sed -e 's/%STUBNAME_TAG%/tusbd/g' $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd > $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd1
sed -e 's/%DAEMONNAME_TAG%/usbsrvd/g' $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd1 > $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd
chmod +x $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd
# copy to root
cp $DEST/usb-redirector-linux-arm-eabi/files/usb* $DEST/output/sdcard/usr/local/bin/ 
cp $DEST/usb-redirector-linux-arm-eabi/files/modules/src/tusbd/tusbd.ko $DEST/output/sdcard/usr/local/bin/ 
cp $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd $DEST/output/sdcard/etc/init.d/
# started by default ----- update.rc rc.usbsrvd defaults
chroot $DEST/output/sdcard /bin/bash -c "update-rc.d rc.usbsrvd defaults"

# hostapd from testing binary replace.
cd $DEST/output/sdcard/usr/sbin/
tar xvfz $SRC/bin/hostapd21.tgz
cp $SRC/config/hostapd.conf $DEST/output/sdcard/etc/


# sunxi-tools
cd $DEST/sunxi-tools
make clean && make -j2 'fex2bin' CC=arm-linux-gnueabihf-gcc && make -j2 'bin2fex' CC=arm-linux-gnueabihf-gcc && make -j2 'nand-part' CC=arm-linux-gnueabihf-gcc
cp fex2bin $DEST/output/sdcard/usr/bin/ 
cp bin2fex $DEST/output/sdcard/usr/bin/
cp nand-part $DEST/output/sdcard/usr/bin/

# cleanup 
# unmount proc, sys and dev from chroot
umount $DEST/output/sdcard/dev/pts
umount $DEST/output/sdcard/dev
umount $DEST/output/sdcard/proc
umount $DEST/output/sdcard/sys

rm $DEST/output/sdcard/usr/bin/qemu-arm-static 
# umount images 
umount $DEST/output/sdcard/ 
losetup -d $LOOP

# let's create nice file name
VERSION="${VERSION/ /_}"
VGA=$VERSION"_vga"
HDMI=$VERSION"_hdmi"
#####

cp $DEST/output/debian_rootfs.raw $DEST/output/$HDMI.raw
cd $DEST/output/
zip $HDMI.zip $HDMI.raw

# let's create VGA version
LOOP=$(losetup -f)
losetup -o 1048576 $LOOP $DEST/output/debian_rootfs.raw
mount $LOOP $DEST/output/sdcard/
sed -e 's/ct-hdmi.bin/ct-vga.bin/g' -i $DEST/output/sdcard/boot/uEnv.ct
sed -e 's/cb2-hdmi.bin/cb2-vga.bin/g' -i $DEST/output/sdcard/boot/uEnv.cb2
umount $DEST/output/sdcard/ 
losetup -d $LOOP
mv $DEST/output/debian_rootfs.raw $DEST/output/$VGA.raw
cd $DEST/output/
zip $VGA.zip $VGA.raw

#!/bin/bash

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script."
    exit 1
fi

cat > .install-exclude <<EOF
/dev/*
/proc/*
/sys/*
/media/*
/mnt/*
/run/*
/tmp/*
/boot/*
EOF

exec 2>/dev/null
umount /mnt
exec 2>&1

clear_console
echo "

                                             
 #    #   ##   #####  #    # # #    #  ####  
 #    #  #  #  #    # ##   # # ##   # #    # 
 #    # #    # #    # # #  # # # #  # #      
 # ## # ###### #####  #  # # # #  # # #  ### 
 ##  ## #    # #   #  #   ## # #   ## #    # 
 #    # #    # #    # #    # # #    #  ####  
                                             


This script will NUKE / erase your NAND partition and copy content of SD card to it

"

echo -n "Proceed (y/n)? (default: y): "
read nandinst

if [ "$nandinst" == "n" ]
then
  exit 0
fi

FLAG=".reboot-nand-install.pid"

if [ ! -f $FLAG ]; then
echo "Partitioning"
apt-get -y -qq install dosfstools
(echo y;) | nand-part -f a20 /dev/nand 32768 'bootloader 32768' 'rootfs 0' >> /dev/null || true
echo "
Press a key to reboot than run this script again!
"
touch $FLAG
read zagon
reboot
exit 0
fi

echo "Formatting and optimizing NAND rootfs ... up to 30 sec"
mkfs.vfat /dev/nand1 >> /dev/null
mkfs.ext4 /dev/nand2 >> /dev/null
tune2fs -o journal_data_writeback /dev/nand2 >> /dev/null
tune2fs -O ^has_journal /dev/nand2 >> /dev/null
e2fsck -f /dev/nand2

echo "Creating NAND bootfs ... few seconds"
mount /dev/nand1 /mnt
tar xfz nand1-cubietruck-debian-boot.tgz -C /mnt/
rm nand1-cubietruck-debian-boot.tgz
rm nand_mbr.backup

#choose proper kernel configuration for CB2 or CT 
if [ $(cat /proc/meminfo | grep MemTotal | grep -o '[0-9]\+') -ge 1531749 ]; then
	cp /boot/uEnv.ct /mnt/uEnv.txt
else
	cp /boot/uEnv.cb2 /mnt/uEnv.txt
fi

cp /boot/uImage /mnt/
cp /boot/*.bin /mnt/

# change root from sd card to nand in both configs
sed -e 's/root=\/dev\/mmcblk0p1/nand_root=\/dev\/nand2/g' -i /mnt/uEnv.txt
# different path
sed -e 's/\/boot\///g' -i /mnt/uEnv.txt
umount /mnt

echo "Creating NAND rootfs ... up to 5 min"
mount /dev/nand2 /mnt
rsync -aH --exclude-from=.install-exclude  /  /mnt
umount /mnt
echo "All done. Press a key to power off, than remove SD and boot from NAND"
rm $FLAG
rm .install-exclude
read konec
poweroff

#!/bin/bash
vmlinux=$(ls /boot/ |grep vml*)
initramfs=$(ls /boot/ |grep initramfs*)
modules=$(ls /lib/modules)
echo "root密码为: redhat"
read -p "请输入你的U盘分区如：/dev/sdb: " disk
fdisk=${disk}1
#磁盘分区
dd if=/dev/zero of=$disk bs=500 count=1
fdisk $disk << DLY
n
p 
1

+2G
a
1
w
DLY
umount $fdisk
mkfs.ext4 $fdisk

rm -rf /mnt/*
mkdir /mnt/usb
mount $fdisk  /mnt/usb/
rm -rf /dev/shm/usb
mkdir -p /dev/shm/usb
mount /dev/cdrom /iso
#安装基本工具
yum -y install filesystem bash coreutils passwd shadow-utils openssh-clients rpm yum net-tools bind-utils vim-enhanced findutils lvm2 util-linux-ng --installroot=/dev/shm/usb/
cp -arv /dev/shm/usb/* /mnt/usb/
cp /boot/$vmlinux  /mnt/usb/boot
cp /boot/$initramfs  /mnt/usb/boot/
cp -arv /lib/modules/$modules  /mnt/usb/lib/modules/

rpm -ivh http://172.25.254.160/grub/grub-0.97-77.el6.x86_64.rpm --root=/mnt/usb/ --nodeps --force

#安装GRUB程序
grub-install --root-directory=/mnt/usb/  --recheck  $disk
cp /boot/grub/grub.conf /mnt/usb/boot/grub/
uuid=$(blkid $fdisk |egrep -o '(.){8}-((.){4}-){3}(.){12}')
cat >/mnt/usb/boot/grub/grub.conf<<DLY
default=0
timeout=5
splashimage=/boot/grub/splash.xpm.gz
hiddenmenu
title My USB Linux (2.6.32-431.el6.x86_64)
        root (hd0,0)
        kernel /boot/$vmlinux ro root=UUID=$uuid selinux=0
        initrd /boot/$initramfs
DLY
cp /etc/skel/.bash* /mnt/usb/root/
cat >/mnt/usb/etc/sysconfig/network<<DLY
NETWORKING=yes
HOSTNAME=usb.hugo.org
DLY

cp /etc/sysconfig/network-scripts/ifcfg-eth0 /mnt/usb/etc/sysconfig/network-scripts/
eth0=/mnt/usb/etc/sysconfig/network-scripts/ifcfg-eth0
cat >${eth0}<<DLY
DEVICE=eth0
BOOTPROTO=none
ONBOOT=yes
USERCTL=no
IPADDR=192.168.0.123
NETMASK=255.255.255.0
GATEWAY=192.168.0.254
DLY
cat >/mnt/usb/etc/fstab<<DLY
UUID=$uuid / ext4 defaults 0 0
sysfs                   /sys                    sysfs   defaults        0 0
proc                    /proc                   proc    defaults        0 0
tmpfs                   /dev/shm                tmpfs   defaults        0 0
devpts                  /dev/pts                devpts  gid=5,mode=620  0 0
DLY

sed -i '1s/*/$1$j5\/sQ\/$OspqNbPU9laYHp761IgVL1/' /mnt/usb/etc/shadow
sync
echo "root密码为：redhat"
umount $fdisk

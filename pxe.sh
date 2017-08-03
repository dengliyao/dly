#!/bin/bash
dhcp(){
	yum -y install dhcp &>/dev/null
    	if [ $? -eq 0 ];then
		echo "install dhcp success"
    	else
		echo "install dhcp fail"
		exit
    	fi
cat >/etc/dhcp/dhcpd.conf<<DLY
allow booting;
allow bootp;

option domain-name "pod0.example.com";
option domain-name-servers 172.25.254.254;
default-lease-time 600;
max-lease-time 7200;
log-facility local7;

subnet 192.168.0.0 netmask 255.255.255.0 {
  range 192.168.0.50 192.168.0.60;
  option domain-name-servers 172.25.254.254;
  option domain-name "pod12.example.com";
  option routers 192.168.0.10;
  option broadcast-address 192.168.0.255;
  default-lease-time 600;
  max-lease-time 7200;
  next-server 192.168.0.16;
  filename "pxelinux.0";
}

class "foo" {
  match if substring (option vendor-class-identifier, 0, 4) = "SUNW";
}

shared-network 224-29 {
  subnet 10.17.224.0 netmask 255.255.255.0 {
    option routers rtr-224.example.org;
  }
  subnet 10.0.29.0 netmask 255.255.255.0 {
    option routers rtr-29.example.org;
  }
  pool {
    allow members of "foo";
    range 10.17.224.10 10.17.224.250;
  }
  pool {
    deny members of "foo";
    range 10.0.29.10 10.0.29.230;
  }
}
DLY
	systemctl restart dhcpd
}

tftp(){
	yum -y install xinetd tftp-server
	    if [ $? -eq 0 ];then
        	echo "install dhcp success"
	    else
        	echo "install dhcp fail"
        	exit
    	    fi
	sed -i '/disable.*/c         disable                 = no' /etc/xinetd.d/tftp
	service xinetd start
	chkconfig xinetd on
}

syslinux(){
	yum -y install syslinux
    if [ $? -eq 0 ];then
        echo "install syslinux success"
    else
        echo "install syslinux fail"
        exit
    fi
	cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
	mkdir /var/lib/tftpboot/pxelinux.cfg
	cd /var/lib/tftpboot/pxelinux.cfg/
	touch default
cat >/var/lib/tftpboot/pxelinux.cfg/default<<DLY
default vesamenu.c32
timeout 60
display boot.msg
menu background splash.jpg
menu title Welcome to Global Learning Services Setup!

label local
        menu label Boot from ^local drive
        menu default
        localhost 0xffff

label install
        menu label Install rhel7
        kernel vmlinuz
        append initrd=initrd.img ks=http://192.168.0.16/myks.cfg
DLY
}

kscfg(){
cd
cat >ks.cfg<<DLY
#version=RHEL7
# System authorization information
auth --enableshadow --passalgo=sha512
# Reboot after installation 
reboot
# Use network installation
url --url="http://192.168.0.16/dvd/"
# Use graphical install
#graphical 
text
# Firewall configuration
firewall --enabled --service=ssh
firstboot --disable 
ignoredisk --only-use=vda
# Keyboard layouts
# old format: keyboard us
# new format:
keyboard --vckeymap=us --xlayouts='us'
# System language 
lang en_US.UTF-8
# Network information
network  --bootproto=dhcp
network  --hostname=localhost.localdomain
#repo --name="Server-ResilientStorage" --baseurl=http://download.eng.bos.redhat.com/rel-eng/latest-RHEL-7/compose/Server/x86_64/os//addons/ResilientStorage
# Root password
rootpw --iscrypted nope 
# SELinux configuration
selinux --disabled
# System services
services --disabled="kdump,rhsmcertd" --enabled="network,sshd,rsyslog,ovirt-guest-agent,chronyd"
# System timezone
timezone Asia/Shanghai --isUtc
# System bootloader configuration
bootloader --append="console=tty0 crashkernel=auto" --location=mbr --timeout=1 --boot-drive=vda 
# 设置boot loader安装选项 --append指定内核参数 --location 设定引导记录的位置
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel
# Disk partitioning information
part / --fstype="xfs" --ondisk=vda --size=6144
%post
echo "redhat" | passwd --stdin root
useradd carol
echo "redhat" | passwd --stdin carol
# workaround anaconda requirements
%end

%packages
@core
%end
DLY

}


http(){
	yum -y install httpd
		if [ $? -eq 0 ];then
			echo "install http success"
		else
			echo "install http fail"
			exit
		fi
	cp ks.cfg /var/www/html/myks.cfg
	chown apache. /var/www/html/myks.cfg
	mkdir /var/www/html/dvd
	mount -o loop /mnt/rhel7.1/x86_64/isos/rhel-server-7.1-x86_64-dvd.iso /var/www/html/dvd/
	setenforce 0
	systemctl restart httpd
}
dhcp
tftp
syslinux
mount -o  loop /mnt/rhel7.1/x86_64/isos/rhel-server-7.1-x86_64-dvd.iso  /media/
cd /media/isolinux
cp vesamenu.c32 boot.msg vmlinuz initrd.img /var/lib/tftpboot/
cd
kscfg
http

read -p "ip: "  ip
read -p "ip网段：" ip_net
read -p "ip范围开头：" ip1
read -p "ip范围结束: " ip2
#配置SELinux, firewalld, 计算机名称, 本地yum源，IP地址
sed -i --follow-symlinks '/^SELINUX=/c \SELINUX=disabled' /etc/sysconfig/selinux
systemctl stop firewalld &> /dev/null
systemctl disable firewalld &> /dev/null
iptables -F &> /dev/null
mkdir /opt/software &> /dev/null &> /dev/null
mount /dev/sr0 /opt/software &> /dev/null
mkdir /etc/yum.repos.d/bak &> /dev/null
mv /etc/yum.repos.d/C* /etc/yum.repos.d/bak &> /dev/null
cat << eof > /etc/yum.repos.d/centos7_2.repo
[centos7_2]
name=centos7_2
baseurl=file:///opt/software
enable=1
gpgcheck=0
eof

sed -i '/^BOOTPROTO=/c \BOOTPROTO=none' /etc/sysconfig/network-scripts/ifcfg-eno16777736

sed -i '/^IPADDR/d' /etc/sysconfig/network-scripts/ifcfg-eno16777736
sed -i '/^PREFIX/d' /etc/sysconfig/network-scripts/ifcfg-eno16777736 
echo "IPADDR=$ip" >> /etc/sysconfig/network-scripts/ifcfg-eno16777736
echo "PREFIX=24" >> /etc/sysconfig/network-scripts/ifcfg-eno16777736
nmcli connection reload
nmcli connection up eno16777736 &> /dev/null

yum clean all &> /dev/null
yum repolist all
ifconfig

echo "初始化完成"

#安装软件
yum install -y dhcp tftp-server xinetd syslinux vsftpd &> /dev/null

rpm -q dhcp tftp-server xinetd syslinux vsftpd
echo "软件安装成功"

mkdir /var/ftp/centos7.2  &> /dev/null

\cp -f -r /opt/software/* /var/ftp/centos7.2/ & &> /dev/null

sleep 30s
sync
sleep 30s

echo "查看进程"
systemctl start vsftpd
systemctl restart vsftpd
systemctl enable vsftpd  &> /dev/null

ss -antp | grep :21

#编辑dhcp
\cp -f /usr/share/doc/dhcp-4.2.5/dhcpd.conf.example /etc/dhcp/dhcpd.conf

sed -i "27c \subnet $ip_net netmask 255.255.255.0 {\nrange $ip1 $ip2;\nnext-server $ip;\nfilename \"pxelinux.0\";" /etc/dhcp/dhcpd.conf

systemctl start dhcpd
systemctl restart dhcpd 
systemctl enable dhcpd &> /dev/null

ss -anup | grep :67

#配置tftp服务
\cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
\cp /opt/software/isolinux/* /var/lib/tftpboot/
mkdir /var/lib/tftpboot/centos7.2 &> /dev/null

mv /var/lib/tftpboot/vmlinuz /var/lib/tftpboot/initrd.img /var/lib/tftpboot/centos7.2 &> /dev/null
mkdir /var/lib/tftpboot/pxelinux.cfg/ &> /dev/null
\cp -f /var/lib/tftpboot/isolinux.cfg /var/lib/tftpboot/pxelinux.cfg/default
sed -i '61,$d' /var/lib/tftpboot/pxelinux.cfg/default

sed -i "60c \label linux\nmenu label ^Install CentOS7.2\nkernel centos7.2/vmlinuz\nappend initrd=centos7.2/initrd.img inst.stage2=ftp://$ip/centos7.2 inst.repo=ftp://$ip/centos7.2 ks=ftp://$ip/centos7_2.cfg" /var/lib/tftpboot/pxelinux.cfg/default

sed -i '/disable/s|yes|no|' /etc/xinetd.d/tftp

systemctl restart xinetd
systemctl enable xinetd
\cp -f anaconda-ks.cfg /var/ftp/centos7_2.cfg
sed -i 's|^cdrom$||' /var/ftp/centos7_2.cfg
sed -i "s|^graphical|url --url=\"ftp://$ip/centos7.2\"|" /var/ftp/centos7_2.cfg

echo -e "# Reboot after installation\nreboot">> /var/ftp/centos7_2.cfg
systemctl restart xinetd
systemctl restart vsftpd
chmod 644 /var/ftp/centos7_2.cfg
echo "测试吧"

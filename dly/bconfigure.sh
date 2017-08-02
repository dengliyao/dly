#/bin/bash
setenforce 0
iptables -F

yum install openldap openldap-clients nss-pam-ldapd -y

#通过证书连接ldap服务器
authconfig --enableldap --enableldapauth --ldapserver=servera.pod12.example.com --ldapbasedn="dc=example,dc=org" --enableldaptls --ldaploadcacert=http://servera.pod12.example.com/ca.crt  --update

#安装autofs挂载家目录并配置
yum -y install autofs
cat >>/etc/auto.master<<DLY
/ldapuser /etc/auto.ldap
DLY
cat >>/etc/auto.ldap<<DLY
*       -rw,soft,intr 172.25.12.10:/ldapuser/&
DLY
service autofs start

#安装启动vsftpd
yum install vsftpd -y
systemctl start vsftpd
systemctl enable vsftpd


#搭建http基于帐号认证
yum -y install httpd
yum -y install wget

#安装apache 连接ldap的模块 mod_ldap.so
wget -r ftp://172.25.254.250/notes/project/UP200/UP200_ldap-master/openldap/pkg/
cd 172.25.254.250/notes/project/UP200/UP200_ldap-master/openldap/pkg/
rpm -ivh apr-util-ldap-1.5.2-6.el7.x86_64.rpm mod_ldap-2.4.6-31.el7.x86_64.rpm

#下载ca证书
wget http://servera.pod12.example.com/ca.crt -O /etc/httpd/ca.crt
cd

#配置apache虚拟主机
cat >/etc/httpd/conf.d/www.ldapuser.com.conf<<DLY
LDAPTrustedGlobalCert CA_BASE64 /etc/httpd/ca.crt
<VirtualHost *:80>
        ServerName www.ldapuser.com
        DocumentRoot /var/www/ldapuser.com
        <Directory "/var/www/ldapuser.com">
                AuthName ldap
                AuthType basic
                AuthBasicProvider ldap
                AuthLDAPUrl "ldap://servera.pod12.example.com/dc=example,dc=org" TLS
                Require valid-user
        </Directory>
</VirtualHost>
DLY

service httpd restart
systemctl enable httpd
mkdir -p /var/www/ldapuser.com
echo "welcome to ldapserver from serverb1" > /var/www/ldapuser.com/index.html


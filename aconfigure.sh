#!/bin/bash
iptables -F;setenforce 0

#安装软件
yum install openldap-clients migrationtools openldap-servers openldap -y

#生成配置文件slapd.conf
cat >/etc/openldap/slapd.conf<<DLY
include         /etc/openldap/schema/corba.schema
include         /etc/openldap/schema/core.schema
include         /etc/openldap/schema/cosine.schema
include         /etc/openldap/schema/duaconf.schema
include         /etc/openldap/schema/dyngroup.schema
include         /etc/openldap/schema/inetorgperson.schema
include         /etc/openldap/schema/java.schema
include         /etc/openldap/schema/misc.schema
include         /etc/openldap/schema/nis.schema
include         /etc/openldap/schema/openldap.schema
include         /etc/openldap/schema/pmi.schema
include         /etc/openldap/schema/ppolicy.schema
include         /etc/openldap/schema/collective.schema
allow bind_v2
pidfile         /var/run/openldap/slapd.pid
argsfile        /var/run/openldap/slapd.args
####  Encrypting Connections
TLSCACertificateFile /etc/pki/tls/certs/ca.crt
TLSCertificateFile /etc/pki/tls/certs/slapd.crt
TLSCertificateKeyFile /etc/pki/tls/certs/slapd.key
### Database Config###          
database config
rootdn "cn=admin,cn=config"
rootpw {SSHA}IeopqaxvZY1/I7HavmzRQ8zEp4vwNjmF
access to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * break
### Enable Monitoring
database monitor
# allow only rootdn to read the monitor
access to * by dn.exact="cn=admin,cn=config" read by * none
DLY

#转换格式与修改权限
rm -rf /etc/openldap/slapd.d/*
slaptest -f /etc/openldap/slapd.conf -F /etc/openldap/slapd.d
chown -R ldap:ldap /etc/openldap/slapd.d
chmod -R 000 /etc/openldap/slapd.d
chmod -R u+rwX /etc/openldap/slapd.d

#下载脚本自动生成
wget ftp://172.25.254.250/notes/project/UP200/UP200_ldap-master/openldap/other/mkcert.sh
chmod +x mkcert.sh
./mkcert.sh --create-ca-keys
./mkcert.sh --create-ldap-keys
cd /etc/pki/CA/
cp my-ca.crt /etc/pki/tls/certs/ca.crt
cp ldap_server.key /etc/pki/tls/certs/slapd.key
cp ldap_server.crt  /etc/pki/tls/certs/slapd.crt
cd ~

#生成数据库目录及DB_CONFIG文件
rm -rf /var/lib/ldap/*
chown ldap.ldap /var/lib/ldap
cp -p /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
chown ldap. /var/lib/ldap/DB_CONFIG
systemctl start  slapd.service


#创建用户数据库
mkdir ~/ldif
cat >/root/ldif/bdb.ldif<<DLY
dn: olcDatabase=bdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcBdbConfig
olcDatabase: {1}bdb
olcSuffix: dc=example,dc=org
olcDbDirectory: /var/lib/ldap
olcRootDN: cn=Manager,dc=example,dc=org
olcRootPW: redhat
olcLimits: dn.exact="cn=Manager,dc=example,dc=org" time.soft=unlimited time.hard=unlimited size.soft=unlimited size.hard=unlimited
olcDbIndex: uid pres,eq
olcDbIndex: cn,sn,displayName pres,eq,approx,sub
olcDbIndex: uidNumber,gidNumber eq
olcDbIndex: memberUid eq
olcDbIndex: objectClass eq
olcDbIndex: entryUUID pres,eq
olcDbIndex: entryCSN pres,eq
olcAccess: to attrs=userPassword by self write by anonymous auth by dn.children="ou=admins,dc=example,dc=org" write  by * none
olcAccess: to * by self write by dn.children="ou=admins,dc=example,dc=org" write by * read
DLY

ldapsearch -x -b "cn=config" -D "cn=admin,cn=config" -w config -h localhost dn -LLL | grep -v ^$
ldapadd -x -D "cn=admin,cn=config" -w config -f ~/ldif/bdb.ldif -h localhost
ldapsearch -x -b "cn=config" -D "cn=admin,cn=config" -w config -h localhost dn -LLL | grep -v ^$ |tail -1
sed -i 's/^$DEFAULT_MAIL_DOMAIN = .*/$DEFAULT_MAIL_DOMAIN = "example.org";/' /usr/share/migrationtools/migrate_common.ph
sed -i 's/^$DEFAULT_BASE = ".*/$DEFAULT_BASE = "dc=example,dc=org";/' /usr/share/migrationtools/migrate_common.ph

#新建测试用户与组（指定加目录）
mkdir /ldapuser
groupadd -g 10000 ldapuser1
useradd -u 10000 -g 10000 ldapuser1 -d /ldapuser/ldapuser1
groupadd -g 10001 ldapuser2
useradd -u 10001 -g 10001 ldapuser2 -d /ldapuser/ldapuser2
echo uplooking | passwd --stdin ldapuser1
echo uplooking | passwd --stdin ldapuser2
grep ^ldapuser /etc/passwd > /root/passwd.out
grep ^ldapuser /etc/group > /root/group.out
cd /usr/share/migrationtools/
./migrate_base.pl > /root/ldif/base.ldif
./migrate_passwd.pl /root/passwd.out  > /root/ldif/password.ldif
./migrate_group.pl /root/group.out > /root/ldif/group.ldif

#导入数据库
ldapadd -x -D "cn=Manager,dc=example,dc=org" -w redhat -h localhost -f ~/ldif/base.ldif 
ldapadd -x -D "cn=Manager,dc=example,dc=org" -w redhat -h localhost -f ~/ldif/group.ldif 
ldapadd -x -D "cn=Manager,dc=example,dc=org" -w redhat -h localhost -f ~/ldif/password.ldif

#通过http方式共享出ca.crt文件,通过nfs方式共享出用户家目录
yum -y install httpd
cp /etc/pki/tls/certs/ca.crt /var/www/html/
systemctl start httpd
systemctl enable httpd
yum -y install nfs-utils
cat >/etc/exports<<DLY
/ldapuser       172.25.12.0/24(rw,async)
DLY
systemctl restart rpcbind
systemctl restart nfs
echo "测试网络用户为ldapuser1和ldapuser2"
echo "密码为:uplooking"

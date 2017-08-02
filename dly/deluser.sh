#!/bin/bash
#删除ldap服务器用户

read -p "请输入你要删除的用户:" u
id $u &>/dev/null
if [ $? -eq 0 ];then
        ldapdelete -x -D "cn=Manager,dc=example,dc=org" -w redhat "uid=$u,ou=People,dc=example,dc=org"
else
        echo "用户不存在!"
fi

#!/bin/bash

# 尝试创建 /etc/logrotate.d/mongod_ggw 管理日志

#注意：UID范围可以修改，也存在UID≥1000的系统用户，应查阅/etc/login.defs中的UID_MIN。
COMMON_UID_MIN=`awk '/^UID_MIN/ {print $2}' /etc/login.defs`
if [ "$UID" -lt $COMMON_UID_MIN ]; then
	echo "必须以普通用户身份初始化副本集的日志管理设置"
	exit
fi

# readLimit=4	# 可读限制的最低权限
# sdPath=/etc/sudoers

# selfUser=`whoami`
# selfGroups=`groups $selfUser | awk '{print $3}'`
# # echo $selfUser $selfGroups

# #/etc/sudoers 文件 权限、所属用户、所属组
# sdAuth=`stat -c %a $sdPath`
# sdOwner=`stat -c "%U" $sdPath`
# sdGroup=`stat -c "%G" $sdPath`
# # echo "所有者: $sOwner, 所属组: $sGroup"

# auth1=$(($sdAuth / 100))		# 用户权限
# auth2=$(($sdAuth % 100 / 10))	# 组权限
# auth3=$(($sdAuth % 10))			# 其他权限
# # echo $sdAuth $auth1 $auth2 $auth3

# if [ $selfUser == $sdOwner ]; then
# 	# 相同用户
# 	nauth=$auth1
# 	tipAuth=$((readLimit*100 + auth2*10 + auth3))
# elif [ $selfGroups == $sdGroup ]; then
# 	# 相同组
# 	nauth=$auth2
# 	tipAuth=$((auth1*100 + readLimit*10 + auth3))
# else
# 	# 其他权限
# 	nauth=$auth3
# 	tipAuth=$((auth1*100 + auth2*10 + readLimit))
# fi

# # sudoers 文件权限校验
# if [ $nauth -lt $readLimit ]; then
# 	# 临时修改一下 /etc/sudoers 权限
# 	chmod $tipAuth $sdPath
# 	# echo "$selfUser 用户读取 "$sdPath" 失败，请手动将权限设置为 $sdAuth -> $tipAuth chmod $tipAuth $sdPath"
# 	# exit
# fi

# aa=`cat /etc/sudoers | grep -E "^($selfUser)[[:space:]]+ALL=\(ALL\)[[:space:]]+"` | grep -E ".*/usr/sbin/logrotate"
# echo $aa






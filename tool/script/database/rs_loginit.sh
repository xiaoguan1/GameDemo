#!/bin/bash

# 注意：UID范围可以修改，也存在UID≥1000的系统用户，应查阅/etc/login.defs中的UID_MIN。
COMMON_UID_MIN=`awk '/^UID_MIN/ {print $2}' /etc/login.defs`
if [ "$UID" -lt $COMMON_UID_MIN ]; then
	echo "必须以普通用户身份初始化副本集的日志管理设置"
	exit
fi

userName=`whoami`
rsList=`ls ./script/database/rs_env`
rsDb=$HOME/rs_db
rsLogD=$rsDb/logrotate.d
userTempFile=$rsDb/logrotate.d/"$userName"_crontate.tmp

# ----------- 尝试副本集节点进程的数据文件夹 -----------
if [ ! -d $rsDb ]; then
	mkdir $rsDb
fi

if [ ! -d $rsLogD ]; then
	mkdir $rsLogD
fi

for rsName in $rsList; do
	port=$(echo "$rsName" | awk -F'-' '{print $2}' | awk -F '.' '{print $1}')
	portDir="$rsDb"/"$port"
	if [ ! -d $portDir ]; then
		mkdir $portDir
	fi
	if [ ! -d $portDir/data ]; then
		mkdir $portDir/data
	fi
done

userCron=$(crontab -l 2>/dev/null)   # 当前用户的所有crontab信息，（ 2>/dev/null 忽略错误信息）
# echo "$userCron"		# 必须携带双引号
isExist=$(echo "$userCron" | grep bin)	# 检测当前用户是否存在日志管理任务

if [ -z "$isExist" ]; then
	# 在crontab中未找到相关的定时任务，需要插入!!!
	crontab -l > $userTempFile
	echo "aaaaaaa" >> $userTempFile
fi


# ----------- 设置日志 -----------
# a=`crontab -l`
# echo $a
# if [ `crontab -l 2>/dev/null | grep -q "bin"` ]; then
# 	echo "aaaaa"
# else
# 	echo "bbbbbb"
# fi




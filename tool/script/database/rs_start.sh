#!/bin/bash

#注意：UID范围可以修改，也存在UID≥1000的系统用户，应查阅/etc/login.defs中的UID_MIN。
COMMON_UID_MIN=`awk '/^UID_MIN/ {print $2}' /etc/login.defs`
if [ "$UID" -lt $COMMON_UID_MIN ]; then
	echo "必须普通用户启动副本集"
	exit
fi

rsList=`ls ./script/database/rs_env`

rsDbPath=$HOME/rs_db

# 尝试初始化相关文件夹
if [ ! -d "$rsDbPath" ]; then
	# 创建文件
	mkdir "$rsDbPath"
fi

for rsName in $rsList; do
	echo $rsName
	port=$(echo "$rsName" | awk -F'-' '{print $2}' | awk -F'.' '{print $1}')sDbPath/
	echo $port
	#if [ ! -d $rsDbPath/   ]; then
#	fi
done



echo $HOME

rsList=`ls ./script/database/rs_env`

for rsName in $rsList; do
	mPid=`ps -ef | grep $rsName | grep -v grep | awk '{print $2}'`
	if [ -z "$mPid" ] || [ "$mPid" -lt 0 ]; then
		# 启动rsName的mongod副本集进程
		#mongod -f ./script/database/rs_env/"$rsName"
		echo -e "start $rsName finish\n"
	fi	
done

echo "执行完毕"

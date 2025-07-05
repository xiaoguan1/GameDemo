#!/bin/bash

config=$1		# 进程pid的配置文件
if [ "X$config" = "X" ]; then
	echo "stop skynet fail, please input config"
	exit
fi

McsPort=`cat $config | grep "mcs_port" | awk '{print $3}'`
if [ "X$McsPort" = "X" ]; then
	echo "$config not find mcs_port!"
	exit
fi

skynetPid=`ps -ef | grep $config | grep 'skynet' | awk '{print $2}'`
if [ "X$skynetPid" = "X" ]; then
	echo "stop fail, because not find pid!"
	exit
fi

# echo $config $McsPort $skynetPid
wget -q -O - "http://127.0.0.1:$McsPort/closesvc"

while true; do
	# isLive 和 skynetPid 是一样的
	isLive=`ps -ef | grep $config | grep 'skynet' | awk '{print $2}'`
	if [ "X$isLive" = "X" ]; then
		echo "skynet config=\"$config\" stop finish!"
		exit
	fi
	echo "$isLive stoping"
	sleep 1	# 等到1秒
done

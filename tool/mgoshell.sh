#!/bin/bash

mPid=`ps -ef | grep mongodb | grep -v grep | awk '{print $2}'`

if [ "X$mPid" == "X" ]; then
	echo "请先启动 mongodb 服务"
	exit
fi

echo "mongodb pid = $mPid"

/opt/mongodb/bin/mongo --host localhost --port 27017

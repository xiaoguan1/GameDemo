#!/bin/bash
getDir(){
	dir=`echo $0 | grep "^/"`
	if test "${dir}"; then	# test 变量。 dir 为空字符串("") 则为false，否则为true
		dirname $0
	else
		dirname `pwd`/$0
	fi
}
path=`getDir`
echo $path

# 中心数据库脚本
centerdata_create=$path/script/database/centerdata_create.sh
centerdata_insert=$path/script/database/centerdata_insert.sh


echo "选择题:"
select w in 重置中心数据库
do
	case $w in
		重置中心数据库)
			sh $centerdata_create centerdata
			sh $centerdata_insert centerdata
			break
			;;
	esac
done
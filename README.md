# GameDemo
skynet引擎

后续修改目标：尽量不改动skynet引擎内部原生逻辑代码，方便后续升级引擎（升级引擎也要注意看被改动的地方）。

https://github.com/liuhaopen/SkynetMMO          git@github.com:liuhaopen/SkynetMMO.git


在skynet引擎中修改点，如下：
	1. skynet/3rd/lua/lauxlib.c 添加了 clearone接口，提供可清空某个单独文件的加载
	2. skynet.lua添加了一些协议类型


temp目录是一些临时文件，

-- 热更新相关简介
--	tool目录下的文件最好是无调用其他模块，或者仅仅调用lua原生提供的接口
--  macors常量文件，主要是为了写死一些固定的值而设定的，至多调用lua原生接口或者tool目录下接口内容等等
--  game目录下的代码文件，可调用tool和macors两个类型的文件接口内容
-- 注释：目前没有想到很好的手段，从自动化的角度限制 tool、macors、game非法引用的情况。。。。。。
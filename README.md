# GameDemo
skynet引擎

后续修改目标：尽量不改动skynet引擎内部原生逻辑代码，方便后续升级引擎（升级引擎也要注意看被改动的地方）。

https://github.com/liuhaopen/SkynetMMO          git@github.com:liuhaopen/SkynetMMO.git


在skynet引擎中修改点，如下：
	1. skynet/3rd/lua/lauxlib.c 添加了 clearone接口，提供可清空某个单独文件的加载
	2. skynet.lua添加了一些协议类型


temp目录是一些临时文件，


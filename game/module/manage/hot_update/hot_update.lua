local skynet = require "skynet"
local selfnode_name = DPCLUSTER_NODE.node_ipport

-- 热更新的具体逻辑
-- 	热更新后必须保证两个事情：
-- 		1.function env不会改变，因为有大量的逻辑是以来与fenv的，比如callout等
--		2.module里面的table的引用继续有效，并且能够及时更新到
--
-- 	面向对象处理：
--		类模板和对象，对象本质上就是一堆持久化和非持久化的数据，并附加一个元表实现的。
--		所有，在热更新的时候只需要更新类的模板，并将最新的table和旧的table进行比对，进而修改旧的table即可。

--	模块方法处理：
--		使用loadfile加载，每个模块都有特定的env。所有热更新后得到的新的env和旧的env进行比对，并修改旧的env。
--
--	此外，热更新若想新增一个模块则需要在旧的模块中使用Import。而不是在热更新中新增全新未加载的模块

local function _senddisplay()
	local PROXYSVR = Import("game/global/proxysvr.lua")
	local p = PROXYSVR.GetProxyByServiceName("display")
	p.call.AAA()
end

-- 热更新逻辑处理
function Handle_Request(data)
	_senddisplay()
	local updatefile = {
		{ file = "game/global/oop/roleclass.lua", utype = UPDATE_TYPE.IMPORT,}
	}

	local PROXYSVR = Import("game/global/proxysvr.lua")
	local lsvr = PROXYSVR.GetProxy(".launcher", selfnode_name)
	lsvr.call.UPDATE_FILES(updatefile)

	-- local ROLECLASS = Import("game/global/oop/roleclass.lua")
	-- print(ROLECLASS.RoleClass.__ClassType)
	_senddisplay()
	return true
end





local skynet = require "skynet"
local selfnode_name = DPCLUSTER_NODE.node_ipport

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









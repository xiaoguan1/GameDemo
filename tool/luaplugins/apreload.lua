------------------------------------
--- 加载游戏相关的数据
------------------------------------

local skynet = require "skynet"
local skynet_getenv = skynet.getenv
require "skynet.manager"

-- 注册的公共协议
skynet.register_protocol({
	name = "callout",
	id = skynet.PTYPE_CALLOUT,
	unpack = skynet.unpack,
	pack = skynet.pack,
})

-- 节点类型判断
function IsUser()
	return skynet.getenv("node") == USER_NODE	-- user节点
end
function IsCross()
	return skynet.getenv("node") == CROSS_NODE	-- 一般跨服节点
end
function IsCenter()
	return skynet.getenv("node") == CENTER_NODE	-- 中心服务节点
end
function IsAdhoc()
	return skynet.getenv("node") == ADHOC_NODE	-- 中心服务节点
end


SELF_NODE = load("return " .. assert(skynet_getenv("gcluster_node")))()
SELF_IPPORT = assert(skynet_getenv("self_ipport"))
ALL_SERVERID_MAP = load("return " .. assert(skynet_getenv("all_serverId_map")))()

------------------------------------
--- 加载游戏相关的数据
------------------------------------

local skynet = require "skynet"
local skynet_getenv = skynet.getenv
require "skynet.manager"

local load = load
local assert = assert

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

SELF_NODE = load("return " .. assert(skynet_getenv("host_config")))()
SELF_IPPORT = assert(skynet_getenv("self_ipport"))
SERVERID_CONFIG = load("return " .. assert(skynet_getenv("serverId_config")))()
SERVICE_CLUSTERNAME = load("return " .. assert(skynet_getenv("service_clustername")))()

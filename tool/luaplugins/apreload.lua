------------------------------------
--- 加载游戏相关的数据
------------------------------------

local skynet = require "skynet"
local skynet_getenv = skynet.getenv
require "skynet.manager"

local clusterNo = skynet_getenv("cluster_no")
local serverId = skynet_getenv("server_id")

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
	return SELF_NODE.node == USER_NODE	-- user节点
end
function IsCross()
	return SELF_NODE.node == CROSS_NODE	-- 一般跨服节点
end

SELF_NODE = load("return " .. assert(skynet_getenv("self_node")))()
SELF_IPPORT = assert(SELF_NODE.self_ipport)
SERVERID_CONFIG = load("return " .. assert(skynet_getenv("serverId_config")))()
SERVICE_CLUSTERNAME = load("return " .. assert(skynet_getenv("service_clustername")))()
SELF_CLUSTERNAME = string.format(CLUSTER_NAME_FMT, SELF_NODE.node, clusterNo, serverId)

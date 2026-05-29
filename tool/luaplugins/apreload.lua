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

NODE_IP_MAP = false
function LoadNodeIpMap()
	NODE_IP_MAP = {}
	for serverId, cfg in pairs(SERVERID_CONFIG) do
		if not NODE_IP_MAP[cfg.node] then
			NODE_IP_MAP[cfg.node] = {}
		end
		assert(not NODE_IP_MAP[cfg.node][serverId])
		NODE_IP_MAP[cfg.node][serverId] = cfg.self_ipport
	end
end
LoadNodeIpMap()

function GetClusterAddr(clusterName)
	if not clusterName then
		return
	end
	local node, clusterNo, serverId = string.match(clusterName, CLUSTER_NAME_MATCH)
	if node and serverId then
		serverId = tonumber(serverId)
		return NODE_IP_MAP[node] and NODE_IP_MAP[node][serverId]
	end
end
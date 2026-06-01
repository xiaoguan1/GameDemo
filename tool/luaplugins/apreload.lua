------------------------------------
--- 加载游戏相关的数据
------------------------------------

local skynet = require "skynet"
local skynet_getenv = skynet.getenv
require "skynet.manager"
local string = string
local smatch = string.match

local cluster_no = skynet_getenv("cluster_no")
local server_id = skynet_getenv("server_id")

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
SERVERID_CONFIG = load("return " .. assert(skynet_getenv("serverid_config")))()
SERVICE_CLUSTERNAME = load("return " .. assert(skynet_getenv("service_clustername")))()
SELF_CLUSTERNAME = string.format(CLUSTER_NAME_FMT, SELF_NODE.node, cluster_no, server_id)

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

function GetAddrByClusterName(clusterName)
	if not clusterName then
		return
	end
	local node, no, serverId = string.match(clusterName, CLUSTER_NAME_MATCH)
	if node and serverId and cluster_no == no then
		serverId = tonumber(serverId)
		return NODE_IP_MAP[node] and NODE_IP_MAP[node][serverId]
	end
end

function GetAddr(node, serverId)
	if not node or not serverId then
		return
	end
	return NODE_IP_MAP[node] and NODE_IP_MAP[node][serverId]
end

-- 添加rpc协议
if not skynet.get_proto(skynet.PTYPE_RPC) then
	skynet.register_protocol {
		name = "rpc",
		id = skynet.PTYPE_RPC,
		unpack = skynet.unpack,
		pack = skynet.pack,
	}
end
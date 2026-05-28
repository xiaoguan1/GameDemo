
local skynet = require "skynet"
local node = assert(SELF_NODE.node)
local string = string
local sformat = string.format

local string = string
local pairs = pairs
local assert = assert
local pcall = pcall
local table = table
local tconcat = table.concat

local CLUSTER_NAME_MATCH = CLUSTER_NAME_MATCH
local SELF_IPPORT = assert(SELF_IPPORT)
local SERVERID_CONFIG = assert(SERVERID_CONFIG) --集群环境

node_session2co = {}
command = {}
connecting = {}   -- 正在进行节点连接的事件

node_channel = {}	-- 本节点主动连接其他节点的数据缓存
accept_fd = {}		-- 外部节点主动连接本节点的数据缓存

NODE_IP_MAP = false

function SyncGate(isCall, ...)
	assert(CLUSTER_GATE)
	if isCall then
		return skynet.call(CLUSTER_GATE, "lua", ...)
	else
		skynet.send(CLUSTER_GATE, "lua", ...)
	end
end

-- 根据地址获取节点，isConnect：若找不到则进行网络链接
function GetNodeChannel(address, isConnect)
	if isConnect then
		return node_channel[address]
	end
	return rawget(node_channel, address)
end

-- 消息打包
function MsgPack(msg)
	return tconcat({string.pack(">I2", msg:len()), msg})
end

function LoadNodeIpMap()
	NODE_IP_MAP = {}
	for serverId, cfg in pairs(SERVERID_CONFIG) do
		if not NODE_IP_MAP[cfg.node] then
			NODE_IP_MAP[cfg.node] = {}
		end
		if NODE_IP_MAP[cfg.node][serverId] then
			_ERROR_F("cluster_no[%s] server_id[%s] repeat!!!", cfg.node, serverId)
		end
		NODE_IP_MAP[cfg.node][serverId] = cfg.self_ipport
	end
	-- print("NODE_IP_MAP", tool.dumptree(NODE_IP_MAP))
end

-- 解析集群节点名称
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

-- 开启当前节点监听
local function nodeListen(address)
	-- 肯定是当前节点的，所以不用代理了
	local isOk = SyncGate(true, "listen", address)
	if isOk then
		skynet.error(sformat("gcluster listen open %s", address))
	else
		skynet.error("gclusterd listen open fail!")
	end
end

-- 同步信息的超时检测
local function dealOvertime()
	while true do
		skynet.sleep(100) -- 每秒执行
		local n = skynet.now()
		for _session, _data in pairs(node_session2co) do
			if n >= _data[1] then
				pcall(Ghelper.DealResponse, _session, false, skynet.pack("time out"))
			end
		end
	end
end

skynet.start(function ()
	dofile "game/global/log.lua"

	skynet.dispatch("lua", function (session, source, cmd, ...)
		local f = assert(command[cmd])
		f(source, ...)
	end)

	LoadNodeIpMap()
	Ghelper = Import("tool/service/basic/gcluster/gcluster_helper.lua")
	setmetatable(node_channel, { __index = Ghelper.OpenChannel })

	CLUSTER_GATE = skynet.newservice("gcluster_gate", skynet.self())

	-- 暂时调试
	nodeListen(SELF_IPPORT)		-- 开启当前节点 CLUSTER_GATE
	if node ~= "user" then
		-- nodeListen(SELF_IPPORT)		-- 开启当前节点 CLUSTER_GATE
	else
		local t = GetNodeChannel("cross@1_55001", true)
		print("t ", tool.dumptree(t))
	end
	skynet.timeout(0, dealOvertime)
end)

local skynet = require "skynet"
local host_id = tonumber(assert(skynet.getenv("server_id")))
require "skynet.manager"
local util = require "util.core"
local posix = require "posix"
local dpcluster = require "dpcluster.core"
local queue = require "queueplus"
CS = queue()

local table = table
local thas_value = table.has_value

function abort(msg)
	skynet.error(msg)
	skynet.sleep(100)
	skynet.abort()
end

local function _OpenLogPath()
	local alogpath = skynet.getenv("alogpath") -- logpath 日志文件
	if not alogpath then
		-- 设置alogpath
		local node = assert(skynet.getenv("node"))
		alogpath = "./log/" .. node .. "/logpath/"
		skynet.setenv("alogpath", alogpath)
	end

	local logpath = skynet.getenv("logpath")
	if not logpath then
		local lpath = os.date("%Y-%m-%d %H-%M-%S", util.realtime())
		lpath = alogpath .. lpath .. "/"
		skynet.setenv("logpath", lpath)
	end

	skynet.send(".launcher", "lua", "ALL_LOGLAUNCH")
end

local function doGamePreload()
	assert(not skynet.getenv("game_preload"))
	local aPreload = assert(skynet.getenv("apreload"))
	skynet.setenv("game_preload", aPreload)
	dofile(aPreload)
	BuildNamedSvr()
end

skynet.start(function ()
	local nodeInfo = Import("game/global/nodeInfo.lua")
	local allServerIdMap, errMsg = nodeInfo.GetAllNodeData()
	if not allServerIdMap then
		abort(errMsg)
	end
	local gcluster_node = assert(allServerIdMap[host_id])
	local node = assert(gcluster_node.node)
	local self_ipport = assert(gcluster_node.self_ipport)
	skynet.setenv("gcluster_node", tool.dumptree(gcluster_node))
	skynet.setenv("self_ipport", self_ipport)
	skynet.setenv("node", node)
	skynet.setenv("all_serverId_map", tool.dumptree(allServerIdMap))
	doGamePreload()

	dofile "./game/global/log.lua"
	for _, v in ipairs(BASIC_SERVICE) do
		local id = skynet.uniqueservice(v.svr)
		if not id then
			abort(string.format("start service[%s] fail", v.svr))
		end
		skynet.name(v.named, id)
	end

	-- 启动寄生服务
	local function startOterSvr(nodeSvrSeq)
		for _, v in ipairs(nodeSvrSeq) do
			if thas_value(v.host_node, node) and SELF_NODE[v.svr] == SELF_IPPORT then
				local id = skynet.newservice(v.svr)
				if not id then
					abort(string.format("start service[%s] fail", v.svr))
				end
				skynet.name(v.named, id)
			end
		end
	end
	startOterSvr(ADHOC_SERVICE)

	_OpenLogPath()

	print("SELF_NODE ", tool.dumptree(SELF_NODE))
	print("ALL_SERVERID_MAP:", tool.dumptree(ALL_SERVERID_MAP))
	print("BASIC_SERVICE_MAP ", tool.dumptree(BASIC_SERVICE_MAP))
	print("ADHOC_SERVICE_MAP ", tool.dumptree(ADHOC_SERVICE_MAP))
	Import("game/global/rpc/rpc.lua")
end)
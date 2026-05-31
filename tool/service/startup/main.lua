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
		local node = assert(SELF_NODE.node)
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
end

skynet.start(function ()
	local nodeInfo = Import("game/global/nodeInfo.lua")
	local serverConfig, serviceNode = nodeInfo.GetAllNodeData()
	if not serverConfig then
		abort(serviceNode)
	end
	local host_config = assert(serverConfig[host_id])

	skynet.setenv("self_node", tool.dumptree(host_config))
	skynet.setenv("serverid_config", tool.dumptree(serverConfig))
	skynet.setenv("service_clustername", tool.dumptree(serviceNode))
	doGamePreload()

	dofile "./game/global/log.lua"
	for _, v in ipairs(BASIC_SERVICE) do
		local id = skynet.uniqueservice(v.svr)
		if not id then
			abort(string.format("start service[%s] fail", v.svr))
		end
		skynet.name(v.named, id)
	end

	for _, v in ipairs(USER_BASIC_SERVICE) do
		local id = skynet.uniqueservice(v.svr)
		if not id then
			abort(string.format("start service[%s] fail", v.svr))
		end
		skynet.name(v.named, id)
	end

	-- 启动寄生服务
	local startService = host_config.start_service
	local function startOterSvr(nodeSvrSeq)
		for _, v in ipairs(nodeSvrSeq) do
			if startService[v.svr] == SELF_IPPORT then
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
	print("SERVERID_CONFIG:", tool.dumptree(SERVERID_CONFIG))
	print("BASIC_SERVICE_MAP ", tool.dumptree(BASIC_SERVICE_MAP))
	print("ADHOC_SERVICE_MAP ", tool.dumptree(ADHOC_SERVICE_MAP))
	print("SERVICE_CLUSTERNAME ", tool.dumptree(SERVICE_CLUSTERNAME))
	RPC = Import("game/global/rpc/rpc.lua")

	RPC.mod_call.display["127.0.0.1:11111"].moduleName.funcName(1,2, 3, "4444a")

	RPC.mod_call.display.moduleName.funcName(111,4444, 3, "4444a")
end)
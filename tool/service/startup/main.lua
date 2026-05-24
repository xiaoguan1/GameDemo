local skynet = require "skynet"
local host_id = tonumber(assert(skynet.getenv("server_id")))
require "skynet.manager"
local util = require "util.core"
local posix = require "posix"
local dpcluster = require "dpcluster.core"
local queue = require "queueplus"
CS = queue()

function abort(msg)
	skynet.error(msg)
	skynet.sleep(100)
	skynet.abort()
end

local function _OpenLogPath()
	local alogpath = skynet.getenv("alogpath")
	if not alogpath then
		local _print = _ERROR or skynet.error
		_print("open logpath error, Please set skynet env alogpath!")
		return
	end

	local logpath = skynet.getenv("logpath")
	if not logpath then
		local lpath = os.date("%Y-%m-%d %H-%M-%S", util.realtime())
		lpath = alogpath .. lpath .. "/"
		skynet.setenv("logpath", lpath)
	end

	skynet.send(".launcher", "lua", "ALL_LOGLAUNCH")
end


skynet.start(function ()
	local nodeInfo = Import("game/global/nodeInfo.lua")
	local allNodeData, errMsg = nodeInfo.GetAllNodeData()
	if not allNodeData then
		abort(errMsg)
	end
	print("allNodeData ", tool.dumptree(allNodeData), host_id)
	local gcluster_node = assert(allNodeData[host_id])
	local node = assert(gcluster_node.node)
	local self_ipport = assert(gcluster_node.self_ipport)
	skynet.setenv("gcluster_node", tool.dumptree(gcluster_node))
	skynet.setenv("self_ipport", self_ipport)
	skynet.setenv("node", node)
	skynet.setenv("all_gcluster_node", tool.dumptree(allNodeData))
	DPCLUSTER_NODE = gcluster_node
	SELF_IPPORT = self_ipport

	dofile "./game/global/log.lua"
	for _, v in ipairs(UNIQ_SERVICE_SEQ) do
		local id = skynet.uniqueservice(v.svr)
		if not id then
			abort(string.format("start service[%s] fail", v.svr))
		end
		skynet.name(v.named, id)
	end


	for _, v in ipairs(USER_MUST_SERVICE_SEQ) do
		local id = skynet.newservice(v.svr)
		if not id then
			abort(string.format("start service[%s] fail", v.svr))
		end
		skynet.name(v.named, id)
	end


	if DPCLUSTER_NODE.jlogin then
		-- 需要在当前user节点中，代理启动jlogin服务
		local id = skynet.newservice(JLOGIN_SERVICE.svr)
		if not id then
			abort(string.format("start service[%s] fail", JLOGIN_SERVICE.svr))
		end
		skynet.name(JLOGIN_SERVICE.named, id)
	end

	_OpenLogPath()
end)
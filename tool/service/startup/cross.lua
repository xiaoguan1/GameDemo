local skynet = require "skynet"
local host_id = assert(tonumber(skynet.getenv("server_id")))
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

local function _GetAllFiles(path, result)
	result = result or {}
	path = path or "./game"
	for file in posix.files(path) do
		if file ~= "." and file ~= ".." and file ~= ".git" and file ~= ".svn" then
			file = path .. "/" .. file
			local t = posix.stat(file) or {}
			if t.type == "directory" then				-- 目录
				_GetAllFiles(file, result)
			elseif t.type == "regular" then				-- 文件
				if string.endswith(file, ".lua") then
					result[file] = t.mtime
				end
			else
				skynet.error("error file type " .. file)
			end
		end
	end
	return result
end

local function doGamePreload()
	assert(not skynet.getenv("game_preload"))
	local aPreload = assert(skynet.getenv("apreload"))
	skynet.setenv("game_preload", aPreload)
	dofile(aPreload)
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
	skynet.setenv("node", node)	-- 该进程的节点类型
	skynet.setenv("all_serverId_map", tool.dumptree(allServerIdMap))
	doGamePreload()

	print("gcluster_node ", tool.dumptree(gcluster_node))

	dofile "./game/global/log.lua"
	for _, v in ipairs(UNIQ_SERVICE_SEQ) do
		local id = skynet.uniqueservice(v.svr)
		if not id then
			abort(string.format("start service[%s] fail", v.svr))
		end
		skynet.name(v.named, id)
	end

	if IsCross() then
		for _, v in ipairs(CROSS_MUST_SERVICE_SEQ) do
			local id = skynet.newservice(v.svr)
			if not id then
				abort(string.format("start service[%s] fail", v.svr))
			end
			skynet.name(v.named, id)
		end
	end

	-- adhoc 和 center节点服务
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
	startOterSvr(ADHOC_SERVICE_SEQ)


	print("SERVICES_CONFIG:", tool.dumptree(SERVICES_CONFIG))
end)
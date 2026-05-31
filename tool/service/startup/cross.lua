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
	local serverConfig, serviceNode = nodeInfo.GetAllNodeData()
	if not serverConfig then
		abort(serviceNode)
	end
	local host_config = assert(serverConfig[host_id])

	skynet.setenv("self_node", tool.dumptree(host_config))
	skynet.setenv("serverid_config", tool.dumptree(serverConfig))
	skynet.setenv("service_clustername", tool.dumptree(serviceNode))
	doGamePreload()

	-- print("serverid_config ", tool.dumptree(serverConfig))

	dofile "./game/global/log.lua"
	for _, v in ipairs(BASIC_SERVICE) do
		local id = skynet.uniqueservice(v.svr)
		if not id then
			abort(string.format("start service[%s] fail", v.svr))
		end
		skynet.name(v.named, id)
	end

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

	Import("game/global/rpc/rpc.lua")
	_DEBUG_F("serverConfig %s", tool.dumptree(serverConfig))
	_DEBUG_F("service_clustername %s", tool.dumptree(serviceNode))
	_DEBUG_F("serverConfig %s", tool.dumptree(serverConfig))
	_DEBUG_F("NODE_IP_MAP %s", tool.dumptree(NODE_IP_MAP))
end)
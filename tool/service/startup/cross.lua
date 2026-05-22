local skynet = require "skynet"
require "skynet.manager"
local util = require "util.core"
local posix = require "posix"
local dpcluster = require "dpcluster.core"
local queue = require "queueplus"
local node = skynet.getenv("node")
CS = queue()

function abort(msg)
	print(msg)
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

skynet.start(function ()
	local nodeInfo = Import("game/global/nodeInfo.lua")
	local isOk, self_ipport, gcluster_node = nodeInfo.GetNodeData()
	if not isOk then
		abort(dpcluster)
	end
	skynet.setenv("gcluster_node", tool.dumptree(gcluster_node))
	skynet.setenv("self_ipport", self_ipport)
	DPCLUSTER_NODE = gcluster_node
	SELF_IPPORT = self_ipport

	-- dofile "./game/global/log.lua"
	for _, v in pairs(UNIQ_SERVICE_SEQ) do
		local id = skynet.uniqueservice(v.svr)
		if not id then
			abort(string.format("start service[%s] fail", v.svr))
		end
		skynet.name(v.named, id)
	end

	if IsCross() then
		for _, service in pairs(CROSS_SERVICE_SEQ) do
			-- local id = skynet.newservice(service)
			-- skynet.name(CROSS_SERVICE_CFG[service].named, id)
		end
	end




end)
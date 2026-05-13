local skynet = require "skynet"
require "skynet.manager"
local util = require "util.core"
local posix = require "posix"
local dpcluster = require "dpcluster.core"
local queue = require "queueplus"
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
	local isOk, dpcluster = nodeInfo.GetCrossNodeInfoByDatabase()
	if not isOk then
		abort(dpcluster)
	end
	skynet.setenv("dpcluster", tool.dumptree(dpcluster))
	DPCLUSTER_NODE = dpcluster

	dofile "./game/global/log.lua"
	for _, v in pairs(START_UNIQ_SERVICE) do
		local id = skynet.uniqueservice(v.svr)
		skynet.name(v.named, id)
	end
	-- Import("game/global/dpcluster.lua")

	-- local self_ipport = DPCLUSTER_NODE.node_ipport
	-- for _, service in pairs(CROSS_SERVICE_STARTSEQ) do
	-- 	local id = skynet.newservice(service)
	-- 	skynet.name(CROSS_SERVICE_CFG[service].named, id)
	-- end



end)
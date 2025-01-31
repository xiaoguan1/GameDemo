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

skynet.start(function ()
	local nodeInfo = Import("game/global/nodeInfo.lua")
	local isOk, dpcluster = nodeInfo.GetGameNodeInfoByDatabase()
	if not isOk then
		abort(dpcluster)
	end
	skynet.setenv("dpcluster", tool.dumptree(dpcluster))

	for _, v in pairs(UNIQUE_SERVER_NODE) do
		local id = skynet.uniqueservice(v.svr)
		skynet.name(v.named, id)
	end
	Import("game/global/dpcluster.lua")
	-- skynet.uniqueservice("stimer")
	-- skynet.newservice("databased")
	-- skynet.uniqueservice("dpclusterd")
end)
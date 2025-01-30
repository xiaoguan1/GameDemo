local skynet = require "skynet"
local util = require "util.core"
local posix = require "posix"
local dpcluster = require "dpcluster.core"
local queue = require "queueplus"
CS = queue()

skynet.start(function ()
	local nodeInfo = Import("game/global/nodeInfo.lua")
	local a, b = nodeInfo.GetGameNodeInfoByDatabase()
	print(tool.dumptree(b))


	-- skynet.uniqueservice("stimer")
	-- skynet.newservice("databased")
	-- skynet.uniqueservice("dpclusterd")
end)
local skynet = require "skynet"
local util = require "util.core"
local posix = require "posix"
local dpcluster = require "dpcluster.core"

skynet.start(function ()
	print(util, posix, dpcluster)
end)
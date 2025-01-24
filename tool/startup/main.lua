local skynet = require "skynet"
local util = require "util.core"
local posix = require "posix"
local dpcluster = require "dpcluster.core"

skynet.start(function ()
	util.set_checkuid_service(skynet.self())
	print(util.new_sid(1, 1))
	print(util.new_uid(1, skynet.self()))
end)

local skynet = require "skynet"
local PROXYSVR = Import("game/global/proxysvr.lua")
local DBSERVER = PROXYSVR.GetProxyByServiceName("dbserver", "db")

skynet.register_protocol({
	name = "db",
	id = skynet.PTYPE_DB,
	pack = skynet.pack,
	unpack = skynet.unpack,
})

function Call_ShowTables()
	local a, b, c = DBSERVER.call.showtables(skynet.self())
	print(tool.dump(a))
	return DBSERVER.call.showtables(skynet.self())
end















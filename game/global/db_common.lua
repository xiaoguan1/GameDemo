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
	return DBSERVER.call.showtables(skynet.self())
end

function Send_ModCreateNexist(saveName)
	DBSERVER.send.modcreatenexist(saveName)
end

function Call_ModGetData(saveName)
	return DBSERVER.call.modgetdata(saveName)
end











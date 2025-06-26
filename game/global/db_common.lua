local skynet = require "skynet"
local PROXYSVR = Import("game/global/proxysvr.lua")
local DBSERVER = PROXYSVR.GetProxyByServiceName("dbserver", "db")
local mysql = require "skynet.db.mysql"

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

function Send_ModSave(saveName, saveData)
	assert(saveName and saveData)
	saveName = tool.serialise(saveName)
	saveData = mysql.quote_sql_str(tool.serialise(saveData))
	DBSERVER.send.modsave(saveName, saveData)
	return saveData:len()
end

function Call_ModSave(saveName, saveData)
	assert(saveName and saveData)
	saveName = tool.serialise(saveName)
	saveData = mysql.quote_sql_str(tool.serialise(saveData))
	DBSERVER.call.modsave(saveName, saveData)
end







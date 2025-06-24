local skynet = require "skynet"
require "skynet.manager"
local mysql = require "skynet.db.mysql"
local database_info = load("return " .. skynet.getenv("database_info"))
assert(database_info)
local no = ...
assert(no)

ACCEPT, RESPONSE = {}, {}
local MISC = Import("game/service/dbcell/dbcell_misc.lua")
local MODDATA_DEFAULT = mysql.quote_sql_str('{}')

-- 心跳方法
local HbTime = 1 * 100
function Heartbeat()
	while true do
		skynet.sleep(HbTime)
		TryCall(MISC.DumpCache)
	end
end

-- send方法
function ACCEPT.Insert_Cache(cache)
	MISC.InsertCache(cache)
end

function ACCEPT.modcreatenexist(saveName)
	local db = MISC.ConnDb()
	if not db or not saveName then
		return
	end

	-- INSERT IGNORE : 在唯一索引或主键冲突时什么都不做
	saveName = mysql.quote_sql_str(saveName)
	local sql = string.format("insert ignore into module(mod_name, data) values (%s, %s);",
			saveName, MODDATA_DEFAULT)
	local result = db:query(sql)
	if not result or result.badresult then
		_ERROR_F("saveName:%s result:%s", saveName, tool.dumptree(result))
		return
	end
	return true
end

function ACCEPT.modsave(saveName, saveData)
	local db = MISC.ConnDb()
	if not db or not saveName or not saveData then
		_ERROR_F("modsave saveName:%s saveData:%s fail", saveName, saveData)
		return
	end
	local sql = string.format("update module set data = %s where mod_name = %s;", saveData, saveName)
	local result = db:query(sql)
	if not result or result.badresult then
		_ERROR_F("saveName:%s result:%s", saveName, tool.dumptree(result))
	end
end

-- call方法
function RESPONSE.showtables()
	local db = MISC.ConnDb()
	local result = db:query("show tables;")
	return result
end

function RESPONSE.modgetdata(saveName)
	local db = MISC.ConnDb()
	if not db or not saveName then
		return
	end
	saveName = mysql.quote_sql_str(saveName)
	local sql = string.format("select data from module where mod_name = %s;", saveName)
	local result = db:query(sql)
	if not result or result.badresult then
		_ERROR_F("saveName:%s result:%s", saveName, tool.dumptree(result))
		return
	end
	return result[1].data
end

function RESPONSE.modsave(saveName, saveData)
	local db = MISC.ConnDb()
	if not db or not saveName or not saveData then
		_ERROR_F("modsave saveName:%s saveData:%s fail", saveName, saveData)
		return
	end
	local sql = string.format("update module set data = %s where mod_name = %s;", saveData, saveName)
	local result = db:query(sql)
	if not result or result.badresult then
		_ERROR_F("saveName:%s result:%s", saveName, tool.dumptree(result))
	end
end

skynet.start(function ()
	dofile "./game/global/log.lua"
	skynet.register(".DBCELL_" .. no)

	skynet.dispatch("lua", function (session, source, command, ...)
		if session == 0 then
			local func = ACCEPT[command]
			if not func then
				error("not find func:" .. command)
			end
			func(...)
		else
			local func = RESPONSE[command]
			if not func then
				error("not find func:" .. command)
			end
			skynet.retpack(func(...))
		end
	end)

	local _ENV = getfenv(1)
	skynet.fork(_ENV.Heartbeat)
end)








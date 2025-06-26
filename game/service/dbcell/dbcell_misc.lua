local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local skynet_queue = require "skynet_queue"
local database_info = load("return " .. skynet.getenv("database_info"))()

local MODDATA_DEFAULT = mysql.quote_sql_str("{}")

CS_LIST = {}
local function _GetCs(name)
	if not name then
		return
	end
	local cs = CS_LIST[name]
	if cs then
		return cs
	end
	CS_LIST[name] = skynet_queue()
	return CS_LIST[name]
end

DB_HLE = false
function ConnDb()
	if DB_HLE then
		local res = DB_HLE:query("show tables")
		if not res["badresult"] then
			return DB_HLE
		end
		DB_HLE = false
	end

	local function on_connect(db)
		db:query("set charset utf8mb4");
	end
	local db = mysql.connect({
		host = database_info.dbhost,
		port = database_info.dbport,
		database = database_info.dbname,
		user = database_info.dbuser,
		password = database_info.dbuser,
		charset = "utf8mb4",
		max_packet_size = 1024 * 1024 * 1024,
		on_connect = on_connect
	})
	DB_HLE = assert(db, "conn db fail")
	return DB_HLE
end

CACHE_DATA = {}
function DumpCache()
	local db = ConnDb()
	if not db then
		return
	end

	for _, v in pairs(CACHE_DATA) do
		db:query(v)
	end
end

function InsertCache(cache)
	table.insert(CACHE_DATA, cache)
end

-- accept
function ACCEPT.modcreatenexist(saveName)
	local db = ConnDb()
	if not db or not saveName then
		return
	end
	local cs = _GetCs(saveName)
	-- INSERT IGNORE : 在唯一索引或主键冲突时什么都不做
	saveName = mysql.quote_sql_str(saveName)
	local sql = string.format('insert ignore into module(mod_name, data) values (%s, %s);',
			saveName, MODDATA_DEFAULT)
	local result = cs(db.query, db, sql)
	if not result or result.badresult then
		_ERROR_F("saveName:%s result:%s", saveName, tool.dumptree(result))
		return
	end
	return true
end

function ACCEPT.modsave(saveName, saveData)
	local db = ConnDb()
	if not db or not saveName or not saveData then
		_ERROR_F("modsave saveName:%s saveData:%s fail", saveName, saveData)
		return
	end
	local cs = _GetCs(saveName)
	local sql = string.format("update module set data = %s where mod_name = %s;", saveData, saveName)
	local result = cs(db.query, db, sql)
	if not result or result.badresult then
		_ERROR_F("saveName:%s result:%s", saveName, tool.dumptree(result))
	end
end


-- reponse
function RESPONSE.showtables()
	local db = ConnDb()
	local result = db:query("show tables;")
	return result
end

function RESPONSE.modgetdata(saveName)
	local db = ConnDb()
	if not db or not saveName then
		return
	end
	local cs = _GetCs(saveName)
	local sql = string.format("select data from module where mod_name = %s;", mysql.quote_sql_str(saveName))
	local result = cs(db.query, db, sql)
	if not result or table.empty(result) or result.badresult then
		_ERROR_F("saveName:%s result:%s", saveName, tool.dumptree(result))
		return
	end
	return result[1].data
end

function RESPONSE.modsave(saveName, saveData)
	local db = ConnDb()
	if not db or not saveName or not saveData then
		_ERROR_F("modsave saveName:%s saveData:%s fail", saveName, saveData)
		return
	end
	local cs = _GetCs(saveName)
	local sql = string.format("update module set data = %s where mod_name = %s;", saveData, saveName)
	local result = cs(db.query, db, sql)
	if not result or result.badresult then
		_ERROR_F("saveName:%s result:%s", saveName, tool.dumptree(result))
	end
end
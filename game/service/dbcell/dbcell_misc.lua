local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local database_info = load("return " .. skynet.getenv("database_info"))()

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
	assert(db, "conn db fail")
	DB_HLE = db
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
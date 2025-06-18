local skynet = require "skynet"
require "skynet.manager"
local mysql = require "skynet.db.mysql"
local database_info = load("return " .. skynet.getenv("database_info"))
assert(database_info)
local no = ...
assert(no)

ACCEPT, RESPONSE = {}, {}
local MISC = Import("game/module/dbcell/dbcell_misc.lua")

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


-- call方法
function RESPONSE.showtables()
	local db = MISC.ConnDb()
	local result = db:query("show tables;")
	return result
end

skynet.start(function ()
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








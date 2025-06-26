local skynet = require "skynet"
require "skynet.manager"
local mysql = require "skynet.db.mysql"
local database_info = load("return " .. skynet.getenv("database_info"))
assert(database_info)
local no = ...
assert(no)

ACCEPT, RESPONSE = {}, {}
local MISC = Import("game/service/dbcell/dbcell_misc.lua")
local MODDATA_DEFAULT = mysql.quote_sql_str("{}")

-- 心跳方法
local HbTime = 1 * 100
function Heartbeat()
	while true do
		skynet.sleep(HbTime)
		TryCall(MISC.DumpCache)
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
	assert(MISC.ConnDb())
end)








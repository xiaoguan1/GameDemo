local skynet = require "skynet"
require "skynet.manager"
local PROFILE_CMD = Import("game/global/profile_cmd.lua")
local DB_CNT = tonumber(skynet.getenv("database_num")) or 10

local FATHER_SELF, DB_NO = ...
local sonList = {}

if DB_NO then
	-- son databased
	RESPONSE, ACCEPT = {}, {}
	skynet.start(function ()
		-- CALLOUT = Import("lualib/call_out.lua")
		-- DBSAVE = Import("service/databasecell/dbsave.lua")
		skynet.dispatch("lua", function (session, source, command, ...)
			-- local f
			-- local isRecord = PROFILE_CMD.CmdCal_S()
			-- if session == 0 then
			-- 	f = assert(ACCEPT[command])
			-- 	f(...)
			-- else
			-- 	f = assert(RESPONSE[command])	-- 不在本服务回复
			-- 	if command == "closedb" then
			-- 		if source ~= DB_MGRNO then	-- 不是mgr控制关闭的
			-- 			return
			-- 		end
			-- 		skynet.retpack(f(...))
			-- 	else
			-- 		skynet.retpack(f(...))
			-- 	end
			-- end
			-- -- DBSAVE.CheckEnd()
			-- if isRecord then
			-- 	PROFILE_CMD.CmdCal_E(command)
			-- end
		end)
		-- DBSAVE.StartDb()
	end)
else
	-- father databased
	CMD = {}
	skynet.forward_type({[skynet.PTYPE_LUA] = skynet.PTYPE_TRANS}, function ()
		-- PROXYSVR = Import("lualib/base/proxysvr.lua")
		-- local DBALTER = Import("service/databasecell/dbalter.lua")
		-- DBALTER.CreateRoleColumns()
		-- DBALTER.CreateGameLogTable()
		-- DBALTER.CreateSyncDataTable()
		skynet.register_protocol {
			name = "trans",
			id = skynet.PTYPE_TRANS,
			pack = skynet.pack,
			unpack = function (msg, sz)
				local command, assigndata = skynet.unpack(msg, sz)
				return command, assigndata, msg, sz
			end,
			dispatch = function (session, source, command, ...)
				if command == "closealldb" then
					skynet.retpack(CMD.closealldb(...))
				elseif command == "reconnectalldb" then
					skynet.retpack(CMD.reconnectalldb(...))
				else
					CMD.assign(session, source, command, ...)
				end
				skynet.ignoreret()
			end
		}

		for i = 1, DB_CNT do
			local db = skynet.newservice("databased", skynet.self(), i)
			table.insert(sonList, {
				addr = db,
				-- proxy = PROXYSVR.GetProxy(db, SNODE_NAME)
			})
		end

		-- DBCHECK = Import("service/databasecell/dbcheck.lua")
		-- DBCHECK.StartUpCheck()
	end)
end

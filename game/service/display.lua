local skynet = require "skynet"
require "skynet.manager"
local table = table
local string = string
local load = load
local assert = assert
local PROFILE_CMD = Import("game/global/profile_cmd.lua")

local is_crossserver = (skynet.getenv("is_cross") == "true") and true or false

local SELF_ADDR = skynet.self()

ACCEPT = {}
RESPONSE = {}

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = skynet.unpack,
}

skynet.start(function ()
	skynet.dispatch("lua", function (session, _, command, ...)
		local f
		local isRecord = PROFILE_CMD.CmdCal_S()
		if session == 0 then
			f = assert(ACCEPT[command], command)
			f(...)
		else
			f = assert(RESPONSE[command], command)
			if command == "shutdown" then
				f(...)
			else
				skynet.retpack(f(...))
			end
		end
		if isRecord then
			PROFILE_CMD.CmdCal_E(command)
		end
	end)

	skynet.dispatch("client", function (session, _, id, struct_name, proto_data)
		-- local roleObj = CHAR_MGR.GetRoleById(id)
		-- if roleObj then
		-- 	error(string.format("not role by id:%s", id))
		-- end

		-- local isRecord = PROFILE_CMD.CmdCal_S()
		-- roleObj:ResetIdleCnt()
		-- PROTOCOLEVENT.dispatch(id, struct_name, roleObj, proto_data)
		-- if isRecord then
		-- 	PROFILE_CMD.CmdCal_E(struct_name)
		-- end

		if session ~= 0 then
			skynet.retpack(nil)
		end
	end)

	local PROXYSVR = Import("game/global/proxysvr.lua")
	-- local SHUTDOWN_SVR = PROXYSVR.GetProxyByServiceName("shutdown")
	-- SHUTDOWN_SVR.send.register_csdevent(SELF_ADDR)

	if not is_crossserver then
		local proxySvr = PROXYSVR.GetProxy(".DISPLAY", "127.0.0.1:32527", nil, "lua")
		proxySvr.send.AAA()
	end


end)
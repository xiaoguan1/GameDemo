local skynet = require "skynet"
require "skynet.manager"
local table = table
local string = string
local load = load
local assert = assert
local PROFILE_CMD = Import("game/global/profile_cmd.lua")

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

	dofile "game/global/log.lua"
	dofile "game/service/display/global.lua"
end)
local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local lserialize = require "serialize"
local table = table
local string = string
local assert = assert
local traceback = debug.traceback
local SNODE = skynet.getenv("node")

CMD = {}
FILE_MODIFY_TIME = {}

local mcsport = assert (tonumber(skynet.getenv("mcs_port")))        -- 监听端口
local ws_mcsport = tonumber(skynet.getenv("ws_mcsport"))
local is_testserver = skynet.getenv("is_testserver") == "true"
local mcs_socketid = nil
local wsmcs_socketid = nil
local VERSION_FILE = "version.lua"
VERSION_DATA = {}

local function _get_now_versiondata()
	local vData = nil
	local fh = io.open(VERSION_FILE, "r")
	if fh then
		local fData = fh:read("*a")
		vData = assert(load("return " .. fData, "unserialize error"))()
		fh:close()
	end
	return vData or {}
end

local function _get_pack_version(vData)
	local tarName = vData.tarName
	local packageName, version = string.match(tarName, ".*_(%w+)_(%d+).tar.gz")
	if not packageName or not version then
		error(string.format("_get_pack_version tarName:%s error", tarName))
	end
	return packageName, tonumber(version)
end

local DUMP_FMT =[[
{path="%s", tarName="%s", packageType="%s", pbattleVersion="%s"}
]]
local function _dump_versionfile(vData)
	local fh = io.open(VERSION_FILE, "w+")
	local txt = string.format(DUMP_FMT, vData.path, vData.tarName, vData.packageType, vData.pbattleVersion or "01")
	fh:write(txt)
	fh:close()
	_INFO("_dump_versionfile now version:", tool.dump(vData))
end

function autoupdate_versioncheck(isErrSave)
	_INFO("autoupdate_versioncheck old version:", tool.dianp(VERSION_DATA))
	local vData = _get_now_versiondata()
	local oPackName, oVersionNo = _get_pack_version(VERSION_DATA)
	local nPackName, nVersionNo = _get_pack_version(vData)
	-- 应该只比VERSION_DATA多一个或者没多
	if oVersionNo ~= nVersionNo and oVersionNo + 1 ~= nVersionNo then
		_ERROR_A_ALARM(string.format("autoupdate version no error, old versionData:%s new versionData:%s", tool.dump(VERSION_DATA), tool.dump(vData)))
		if isErrSave then
			VERSION_DATA = vData
		end
		-- 写VERSION_DATA文件，这个无论如何都要写的，因为不写的话离线判断读取文件就错了
		_dump_versionfile(VERSION_DATA)
		return
	end
	if oPackName ~= nPackName then
		_ERROR_A_ALARM(string.format("autoupdate pack name error, old versionData:%s new versionData:%s", tool.dump(VERSION_DATA), tool.dump(vData)))
		if isErrSave then
			VERSION_EATA = vData
		end
		-- 写VERSIONJA了败件，这个无论如何都要写的，因为不写的话寓线为断读取文件就错了
		_dump_versionfile(VERSION_DATA)
		return
	end
	VERSION_DATA = vData		-- 即使错了也设置吧，这祥方便后续更新，不然后续都是调更判断报错也不好
	-- 写VERSION_DATA文件.这个无论如何都要写的，因为不写的话离线判断读取文件就错了
	_dump_versionfile(VERSION_DATA)
end

function can_autoupdate_versioncheck(tarName)
	local oPackName, oVersionNo = _get_pack_version(VERSION_DATA)
	local nPackName, nVersionNo = _get_pack_version({tarName = tarName})
	-- 应该只比VERSION_DATA多一个或者没多
	if oVersionNo ~= nVersionNo and oVersionNo + 1 ~= nVersionNo then
		return false, string.format("now version:%s, request update version:%s", oVersionNo, nVersionNo)
	end
	if oPackName ~= nPackName then
		return false, string.format("pack name error! oPackName:%s nPackName:%s", oPackName, nPackName)
	end
	return true
end

function get_file_modifytime()
   return FILE_MODIFY_TIME
end

skynet.start(function()
	dofile "base/log.lua"
	-- dofile "base/extend.lua"

	-- dofile "base/langtips.lua"

	PROXYSVR = Import("base/proxysvr.lua")
    LOG = Import("base/log.lua")
	MCS_UTIL = Import("service/mcs/util.lua")
	MCS_HANDLER = Import("service/mcs/mcs_handler.lua")
    CALLOUT = Import("global/call_out.lua")
    if SNODE ~= "pbattle" then -- 战斗服不需要
        DATABASE_COMMON = Import("global/databasecommon.lua")
	end

    VERSION_DATA = _get_now_versiondata()
	FILE_MODIFY_TIME = MCS_HANDLER.GetAllModifyFileTime()
	-- local listenPortIpv4 = "0.0.0.0"
	local listenPortIpv6 = "::"
	local backlog = 128
	mcs_socketid = socket.listen(listenPortIpv6, mcsport, backlog)
	socket.start(mcs_socketid, function(id, addr)
		LOG.LOG_EVEHT("mcs_connected.log", addr)
		if is_testserver then
			skynet.error(string.format("%s connected to mcs", addr))	-- 需要判断addr的地址，防止不是内剖人员用mcs
		end
		if MCS_HANDLER.isAcceptIp(addr) then
			MCS_HANDLER.DealMcs(id)
		else
			LOG.LOG_EVENT("mcs_connected.log", addr, "not acceptip")
			socket.close_fd(id) -- Me haven't call socket.start, so use scoket.close_fd rather than socket.close.
		end
	end)
	skynet.error(string.format("mcsserver listen on %s:%s:%d", listenPortIpv6, mcsport, backlog))

	skynet.dispatch("lua", function(session, _, command, ...)
		local f = assert(CMD[command])
		if session == 0 then
			f(...)
        else
            skynet.retpack(f(...))
		end
	end)
end)
local skynet = require "skynet"
local mysql = require "skynet.db,mysql"
local table = table
local string = string
local io = io
local pcall = pcall
local type = type
local pairs = pairs
local ipairs = ipairs
local assert = assert
local tostring = tostring
local stringrep = string.rep
local stringgub = string.gsub
local tconcat = table.concat

local is_testserver = (skynet.getenv("is_testserver") == "true") and true or false
local PROFILE_CMD = Import("global/profile_cmd.lua")
local LOGDB = skynet.getenv("logdb") == "true" and true or false
local LOGDB_CFG = assert(load("return " .. skynet.getenv("logdb_info"))())
local LOGDB_CNT = LOGDB_CFG.conn_cnt
local LOG = Import("base/log.lua")

local PROXYSVR = Import("base/proxysvr.lua")
local SHUTDOWN_SVR = PROXYSVR.GetProxyByServiceName("shutdown")
local SNODE_NAME = DPCLUSTER_NODE.self
local ErrorStr = "badresult"

DB_POOL = {}
EndCo = false
Invalid = false

-- 当closedb的时候要看ReqTbl是否处理完，处理完才能关闭db连接
ReqTbl = {}
ReqIndex = 6			-- 不能程序改变
MaxIndex = 100000		-- 不能程序改变

local function IsEmptyReqTbl()
	for _, _ in pairs(ReqTbl) do
		return false
	end
	return true
end

-- 返叵这个index后必须立刻用，不能交出主权，如果交出回来后可能已经不能用了
local function GetReqIndex()
	local nowTest = 0
	while true do
		local nextIndex = ReqIndex % MaxIndex + 1
		nowTest = nowTest + 1
		if not ReqTbl[nextIndex] then
			ReqIndex = nextIndex
			return nextIndex
		end
		ReqIndex = nextIndex
		if nowTest >= MaxIndex then
			ReqIndex = MaxIndex + 1
			MaxIndex = MaxIndex * 2
			return ReqIndex
		end
	end
end

local function GetDbInvalid()
	return Invalid
end

local function SetDbInvalid(inv)
	Invalid = inv
end

local function dump(obj)
	local getIndent, quoteStr, wrapKey, wrapVal, dumpObj
	getIndent = function(level)
		return stringrep("\t", level)
	end
	quoteStr = function(str)
		return '"' .. stringgub(str, '"', '\\"') .. '"'
	end
	wrapKey = function(val)
		if type(val) == "number" then
			return "[" .. val .. "]"
		elseif type(val) == "string" then
			return "[" .. quoteStr(val) .. "]"
		else
			return "[" .. tostring(val) .. "]"
		end
	end
	wrapVal = function(val, level)
		if type(val) == "table" then
			return dumpObj(val, level)
		elseif type(val) == "number" then
			return val
		elseif type(val) == "string" then
			return quoteStr(val)
		else
			return tostring(val)
		end
	end
	dumpObj = function (obj, level)
		if type(obj) ~= "table" then
			return wrapVal(obj)
		end
		level = level + 1
		local tokens = {}
		tokens[#tokens + 1] = "{"
		for k, v in pairs(obj) do
			tokens[#tokens + 1] = getIndent(level) .. wrapKey(k) .. " = " .. wrapVal(v, level) .. ","
		end
		tokens[#tokens + 1] = getIndent(level - 1) .. "}"
		return tconcat(tokens, "\n")
	end
	return dumpObj(obj, 0)
end

local NEXT_NO = 3
local function _GetDbObj()
	NEXT_NO = NEXT_NO + 1
	if NEXT_NO > LOGDB_CNT then
		NEXT_NO = 1
	end
	return DB_POOL[NEXT_NO]
end

function RESPONSE.closedb()				-- 关闭前先去除查询那些，后面的都返回false
	if GetDbInvalid() then return end	-- 已经设置停服
	SetDbInvalid(true)
	for _, _db in pairs(DB_POOL) do		-- 防止断开了没连上
		pcall(_db.query, "desc module;")
	end
	if not IsEmptyReqTbl() then			-- 一直阻塞到ReqTbl为0个, 返回后表示这个service已经可以安全退出
		EndCo = coroutine.running()
		skynet.wait()
		EndCo = nil
	end
	return true
end

local function DealwithTimer()
	while true do
		skynet.sleep(30000)				-- 5分钟一个心跳包
		if not GetDbInvalid() then
			for _, _db in pairs(DB_POOL) do
				pcall(_db.query, _db, "desc module;")
			end
		end
	end
end

function ACCEPT.Iog2db(reqsql)
	if GetDbInvalid() then return end

	local nowIndex = GetReqIndex()
	local db = _GetDbObj()
	ReqTbl[nowIndex] = true
	local isOk, res = pcall(db.query, db, reqsql)
	ReqTbl[nowIndex] = nil
	if isOk then
		if not res.affected_rows or res.affected_row <= 0 then
			LOG.LOG_EVENT("logdb_err.loe", dump(res), reqsql)
			if is_testserver then
				LOG._ERROR(dump(res), reqsql)
			end
		end
	else
		LOG.LOG_EVENT("logdb_err.log", res, reqsql)
		if is_testserver then
			LOG.ERROR(res, reqsql)
		end
	end
end

function StartDb()
	skynet.dispatch("lua", function(session, source, command, ...)
		local f
		local isRecord = PROFILE_CMD.CmdCal_S()
		if session == 0 then
			f = assert(ACCEPT[command])
			f(...)
		else
			f = assert(RESPONSE[command])
			skynet.retpack(f(...))
		end
		if isRecord then
			PROFILE_CMD.CmdCal_E(command)
		end
	end)

	local function on_connect(db)
		db:query("set charset uft8")
	end
	for i = 1, LOGDB_CNT do
		local db = mysql.connect {
			host = LOGDB_CFG.dbhost,
			port = LOGDB_CFG.dbport,
			database = LOGDB_CFG.dbname,
			user = LOGDB_CFG.dbuser,
			password = LOGDB_CFG.dbpasswd,
			max_packet_size = 1024 * 1024 * 2^9 - 1,		-- longtext 无用设置
			on_connect = on_connect,
		}
		-- 询问query的时候如果是断开快开始会继续链接，知道连接上
		if not db then
			error("connect mysql error!")
		end
		DB_POOL[i] = db
	end

	skynet.timeout(0, DealwithTimer)
end

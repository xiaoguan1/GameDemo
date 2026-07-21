local skynet = require "skynet"
require "skynet.manager"
local tinsert = table.insert
local string = string
local mfloor = math.floor
local debug = debug
local traceback = debug.traceback
local os = os
local ostime = os.time
local io = io
local ioopen = io.open
local posix = require "posix"
assert(posix.mkdir_p)

local isShutDown = false
local is_testserver = skynet.getenv("is_testserver") == "true"
local writelog_time = tonumber(skynet.getenv("writelog_time")) or 3
local closefopen_time = tonumber(skynet.getenv("closefopen_time")) or 300	-- 默认3分钟

CMD = {}
CatchLogStr = {}
CacheFopen = {}

local LOG_LEVEL = {
	WRITE_DELAY = 1,
	WRITE_NOW = 2,		-- 立即dump
}

-- local functions --------------------

-- 缓存文件路径的句柄f
local function GetFopen(filePath)
	if type(filePath) ~= "string" then
		return nil, "invalid filePath"
	end
	local temp = CacheFopen[filePath]
	if temp then
		temp.utime = ostime()	-- 更新时间
		return temp.f
	end
	posix.mkdir_p(filePath)
	local f, errMsg = ioopen(filePath, "a")
	if not f then
		return nil, errMsg
	end
	CacheFopen[filePath] = {
		ctime = ostime(), utime = ostime(),	-- 创建、更新时间
		f = f,
	}
	return f
end

local function WriteFile(filePath, logStr)
	local f, errMsg = GetFopen(filePath)
	assert(f, errMsg)
	f:write(logStr)
	f:write("\n")
	f:flush()
end

local function DoOnceWriteLog()
	for filePath, fileCacheLogs in pairs(CatchLogStr) do
		for _, logStr in ipairs(fileCacheLogs) do
			local isOk, errMsg = TryCall(WriteFile, filePath, logStr)
			if is_testserver and not isOk then
				-- 测试环境下才在控制台输出相关报错
				skynet.error("gamelog DoOnceWriteLog: " .. tostring(errMsg))
			end
		end
		CatchLogStr[filePath] = nil
	end
end

local function DoCloseFopen()
	local ntime = ostime()
	for filename, temp in pairs(CacheFopen) do
		if (ntime - temp.utime) >= closefopen_time then
			CacheFopen[filename] = nil
			temp.f:flush()
			temp.f:close()
		end
	end
end



-- 定时器相关回调函数 --------------------
function DealFopenTimer()
	while true do
		skynet.sleep(1000)	-- 10秒
		if isShutDown then return end
		--写文件
		TryCall(DoCloseFopen)
	end
end

function DealwithTimer()
	while true do
		skynet.sleep(100 * writelog_time)
		if isShutDown then return end
		--写文件
		TryCall(DoOnceWriteLog)
	end
end



-- dispatch CMD --------------------
function CMD.writelog(filePath, level, logStr)
	assert(filePath and logStr, "not filePath or logStr")
	if level == LOG_LEVEL.WRITE_NOW then
		local isOk, errMsg = TryCall(WriteFile, filePath, logStr)
		if is_testserver and not isOk then
			-- 测试环境下才在控制台输出相关报错
			skynet.error("CMD.writelog: " .. tostring(errMsg))
		end
	else
		local fileCacheLogs = CatchLogStr[filePath]
		if not fileCacheLogs then
			fileCacheLogs = {}
			CatchLogStr[filePath] = fileCacheLogs
		end
		tinsert(fileCacheLogs, logStr)
	end
end

function CMD.shutdown()
	if isShutDown then return end
	isShutDown = true
	DoOnceWriteLog()
end

-- start service --------------------
skynet.start(function()
	skynet.dispatch("lua", function(session, _, cmd, ...)
		local f = assert(CMD[cmd])
		if cmd == "shutdown" then
			skynet.ret(skynet.pack(f(...)))
		else
			assert(session == 0)
			f(...)
		end
	end)

	skynet.timeout(0, _G.DealwithTimer)
	skynet.timeout(0, _G.DealFopenTimer)
end)

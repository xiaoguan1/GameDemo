local skynet = require "skynet"
require "skynet.manager"
local tinsert = table.insert

local isShutDown = false
local writelog_time = tonumber(skynet.getenv("writelog_time")) or 3

CMD = {}

-- 文件日志相关缓存
CatchLogStr = {}
CacheFopen = {}

-- db日志相关缓存


local LOG_LEVEL = {
	WRITE_DELAY = 1,
	WRITE_NOW = 2,		-- 立即dump
}

-- 定时器相关回调函数 --------------------
function DealFopenTimer()
	while true do
		skynet.sleep(1000)	-- 10秒
		if isShutDown then return end
		--写文件
		TryCall(FileLog.DoCloseFopen)
	end
end

function DealwithTimer()
	while true do
		skynet.sleep(100 * writelog_time)
		if isShutDown then return end
		--写文件
		TryCall(FileLog.DoOnceWriteLog)
	end
end



-- dispatch CMD --------------------
function CMD.writefilelog(filePath, level, logStr)
	assert(filePath and logStr, "writefilelog args invalid")
	if level == LOG_LEVEL.WRITE_NOW then
		local isOk, errMsg = TryCall(FileLog.WriteFile, filePath, logStr)
		if is_testserver and not isOk then
			-- 测试环境下才在控制台输出相关报错
			skynet.error("CMD.writefilelog: " .. tostring(errMsg))
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

function CMD.writedblog(collName, level, logTbl)
	assert(collName and level and next(logTbl), "writedblog args invalid")
	if level == LOG_LEVEL.WRITE_NOW then
		local isOk, errMsg = TryCall(DbLog.WriteDb, collName, logTbl)
		if is_testserver and not isOk then
			-- 测试环境下才在控制台输出相关报错
			skynet.error("CMD.writefilelog: " .. tool.dump(logTbl))
		end
	else

	end
end

function CMD.shutdown()
	if isShutDown then return end
	isShutDown = true
	FileLog.DoOnceWriteLog()
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

	FileLog = Import("tool/service/basic/gamelog/filelog.lua")
	DbLog = Import("tool/service/basic/gamelog/dblog.lua")

	skynet.timeout(0, _G.DealwithTimer)
	skynet.timeout(0, _G.DealFopenTimer)
end)

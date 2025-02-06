local skynet = require "skynet"
require "skynet.manager"
local tinsert = table.insert
local string = string
local mfloor = math.floor
local posix = require "posix"
assert(posix.mkdir_p)

local writelog_time = tonumber(skynet.getenv("writelog_time")) or 3
local CMD = {}
local CatchLogStr = {}
local isShutDown = false

local LOG_LEVEL = {
	WRITE_DELAY = 1,
	WRITE_NOW = 2,
}

-- 将一个str以del分割为若干个table中的元素
-- n为分割次数
function string.split( line, sep, maxsplit )
	if string.len(line) == 0 then
		return {}
	end
	sep = sep or ' '
	maxsplit = maxsplit or 0
	local retval = {}
	local pos = 1
	local step = 0
	while true do
		local from, to = string.find(line, sep, pos, true)
		step = step + 1
		if (maxsplit ~= 0 and step > maxsplit) or from == nil then
			local item = string.sub(line, pos)
			tinsert( retval, item )
			break
		else
			local item = string.sub(line, pos, from-1)
			tinsert( retval, item )
			pos = to + 1
		end
	end
	return retval
end

local function GetTimeLogStr(logStr)
    return "[" .. os.date("%F %T", mfloor(skynet.time())) .. "]" .. logStr
end

function CMD.writelog(filePath, level, logStr, notTime)
	assert(filePath and logStr, "not filePath or logStr")
	if level == LOG_LEVEL.WRITE_NOW then
		local ok, err = xpcall(function()
			posix.mkdir_p(filePath)
			local f = io.open(filePath, 'a')
			if f then
				if notTime then
					f:write(logStr)
				else
					f:write(GetTimeLogStr(logStr))
				end
				f:write("\n")
				f:close()
			end
		end, debug.traceback)	--调用函数
		if not ok then
			skynet.error("CMD.writelog: " .. tostring(err))
		end
	else
		local filePathTbl = CatchLogStr[filePath]
		if not filePathTbl then
			filePathTbl = {}
			CatchLogStr[filePath] = filePathTbl
		end
		local lmsg = nil
		if notTime then
			lmsg = logStr
		else
			lmsg = GetTimeLogStr(logStr)
		end
		local tmpTbl = {
			level, lmsg,
		}
		tinsert(filePathTbl, tmpTbl)
	end
end

local function DoOnceWriteLog()
	local ok, err = xpcall(function()
		for _filePath, _logInfo in pairs(CatchLogStr) do
			print("_filePath ", _filePath)
			posix.mkdir_p(_filePath)
			local f = io.open(_filePath, 'a')
			if f then
				for _, _logStrInfo in ipairs(_logInfo) do
					f:write(_logStrInfo[2])
					f:write("\n")
				end
				f:close()
			end
			CatchLogStr[_filePath] = nil
		end
	end, debug.traceback)    --调用函数
	if not ok then
		skynet.error("gamelog DealwithTimer: " .. tostring(err))
	end
end

local function DealwithTimer()
	while true do
		skynet.sleep(100 * writelog_time)
		if isShutDown then return end
		--写文件
		DoOnceWriteLog()
	end
end

function CMD.shutdown()
	if isShutDown then return end
	isShutDown = true
	DoOnceWriteLog()
end

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

	skynet.timeout(0, DealwithTimer)
end)

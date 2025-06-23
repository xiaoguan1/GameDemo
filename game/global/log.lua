-- 相关资料笔记 有道云搜索："控制台终端颜色输出（日志）"
local skynet = require "skynet"
local posix = require "posix"
local debug = debug
local table = table
local tconcat = table.concat
local os_date = os.date
local print = print
local sformat = string.format
local logStdin = skynet.getenv("log_stdin") == "true"
local node = skynet.getenv("node")
local HEADER = "\27"
local END_FORMAT = "\27[0m"
local PROXYSVR = Import("game/global/proxysvr.lua")
local GAMELOG_SVR = PROXYSVR.GetProxyByServiceName("gamelog")
local tpack = table.pack

local LOG_LEVEL = {
	WRITE_DELAY = 1,
	WRITE_NOW = 2,
}

local _INFO_LOG_PATH = "./log/" .. node .. "/info/"
local _WARN_LOG_PATH = "./log/" .. node .. "/warn/"
local _ERROR_LOG_PATH =	"./log/" .. node .. "/error/"
local _MEM_LOG_PATH = "./log/" .. node .. "/mem/"
local _ERROR_A_ALARM_PATH = "./log/" .. node .. "/runtime/login_alarm/"
local _LOG_EVENT_PATH = "./log/" .. node .. "/log_event/%s/%s"

-- 字体颜色
local FONTCOLOUR = {
	Black	=	"[30",		-- 黑色
	Red		= 	"[31",		-- 红色
	Green	=	"[32",		-- 绿色
	Yellow	=	"[33",		-- 黄色
	Blue	=	"[34",		-- 蓝色
	Purple	=	"[35",		-- 紫色
	Cyan	=	"[36",		-- 青色
	White	=	"[37",		-- 白色
}

-- 背景颜色
local BACKGROUNDCOLOUR = {
	Black	=	";40m",		-- 黑色
	Red		=	";41m",		-- 红色
	Green	=	";42m",		-- 绿色
	Yellow	=	";43m",		-- 黄色
	Blue	=	";44m",		-- 蓝色
	Purple	=	";45m",		-- 紫色
	Cyan	=	";46m",		-- 青色
	White	=	";47m",		-- 白色
}

-- 白字绿底
local INFO_M = HEADER .. FONTCOLOUR.White .. BACKGROUNDCOLOUR.Green

-- 黑子黄底
local WARN_M = HEADER ..  FONTCOLOUR.Black .. BACKGROUNDCOLOUR.Yellow

-- 黑子红底
local ERROR_M = HEADER ..  FONTCOLOUR.Black .. BACKGROUNDCOLOUR.Red

-- 黑子紫底
local MEM_M = HEADER .. FONTCOLOUR.Black .. BACKGROUNDCOLOUR.Purple

-- 绿字黄底
local EVENT_M = HEADER .. FONTCOLOUR.Green .. BACKGROUNDCOLOUR.Yellow

local SERVICE_INFO = sformat("%s %0x ", SERVICE_NAME, skynet.self())

-- 被调用的函数信息
local _FILE_INFO_T = {
	"<",
	SERVICE_INFO,
	"nil",
	":",
	"nil",
	">",
}
local function FileInfo(deep)
	local dInfo = debug.getinfo(deep or 3, "Sl")
	_FILE_INFO_T[3] = dInfo.short_src
	_FILE_INFO_T[5] = dInfo.currentline
	return tconcat(_FILE_INFO_T)
end


-- 输出格式以及颜色
local _LEVEL_COLOR = {
	[1] = INFO_M,
	[2] = WARN_M,
	[3] = ERROR_M,
	[4] = MEM_M,
	[5] = EVENT_M,
}

local function _info_context(fileInfo, msg)
	return tconcat({
		os_date("%Y-%m-%d %H:%M:%S"),
		"[INFO]",
		fileInfo,
		msg,
	}, " ")
end
local function _warn_context(fileInfo, msg)
	return tconcat({
		os_date("%Y-%m-%d %H:%M:%S"),
		"[WARN]",
		fileInfo,
		msg,
	}, " ")
end
local function _error_context(fileInfo, msg)
	return tconcat({
		os_date("%Y-%m-%d %H:%M:%S"),
		"[ERROR]",
		fileInfo,
		msg,
	}, " ")
end
local function _mem_context(fileInfo, msg)
	return tconcat({
		os_date("%Y-%m-%d %H:%M:%S"),
		"[MEM_ALARM]",
		fileInfo,
		msg,
	}, " ")
end
local function _log_event_context(fileInfo, ...)
	local p = table.pack(...)
	local t = {
		os_date("%Y-%m-%d %H:%M:%S"),
		"[LOG_EVENT]",
		fileInfo,
	}
	for i = 1, p.n do
		table.insert(t, tostring(p[i]))
	end
	return tconcat(t, " ")
end

-- 控制台打印
local function _log_print(level, context)
	local color = level and _LEVEL_COLOR[level]
	assert(color, "level is error!")
	print(tconcat({ color, context, END_FORMAT, }))
end

local function LogToFile(pfile, level, ...)
	-- 注意，字符串的链接不能直接table.concat(arg)
	local arg = tpack(...)
	for i = 1, arg.n do
		arg[i] = tostring(arg[i])
	end
	GAMELOG_SVR.send.writelog(pfile, level, tconcat(arg, " "))
end

---- 外部接口 ------------------------------------------------------------------------

function _INFO(...)
	if logStdin then
		local context = _info_context(FileInfo(), ...)
		_log_print(1, context)
	end
	local cfile = sformat("%s%s.log", _INFO_LOG_PATH, os_date("%Y%m%d"))
	LogToFile(cfile, LOG_LEVEL.WRITE_DELAY, FileInfo(), ...)
end
function _INFO_F(fmt, ...)
	local msg = sformat(fmt, ...)
	if logStdin then
		local context = _info_context(FileInfo(), msg)
		_log_print(1, context)
	end
	local cfile = sformat("%s%s.log", _INFO_LOG_PATH, os_date("%Y%m%d"))
	LogToFile(cfile, LOG_LEVEL.WRITE_DELAY, FileInfo(), msg)
end


function _WARN(...)
	if logStdin then
		local context = _warn_context(FileInfo(), ...)
		_log_print(2, context)
	end
	local cfile = sformat("%s%s.log", _WARN_LOG_PATH, os_date("%Y%m%d"))
	LogToFile(cfile, LOG_LEVEL.WRITE_DELAY, FileInfo(), ...)
end
function _WARN_F(fmt, ...)
	local msg = sformat(fmt, ...)
	if logStdin then
		local context = _warn_context(FileInfo(), msg)
		_log_print(2, context)
	end
	local cfile = sformat("%s%s.log", _WARN_LOG_PATH, os_date("%Y%m%d"))
	LogToFile(cfile, LOG_LEVEL.WRITE_DELAY, FileInfo(), msg)
end


local function _L_ERROR(deep, ...)
	local cfile = sformat("%s%s.log", _ERROR_LOG_PATH, os_date("%Y%m%d"))
	LogToFile(cfile, LOG_LEVEL.WRITE_DELAY, FileInfo(deep), ...)
end
function _ERROR(...)
	if logStdin then
		local context = _error_context(FileInfo(), ...)
		_log_print(3, context)
	end
	_L_ERROR(4, ...)
end
function _ERROR_F(fmt, ...)
	local msg = sformat(fmt, ...)
	if logStdin then
		local context = _error_context(FileInfo(), msg)
		_log_print(3, context)
	end
	_L_ERROR(4, msg)
end


function _MEM_ALARM(...)
	if logStdin then
		local context = _mem_context(FileInfo(), ...)
		_log_print(4, context)
	end
	local cfile = sformat("%s%s.log", _MEM_LOG_PATH, os_date("%Y%m%d"))
	LogToFile(cfile, LOG_LEVEL.WRITE_DELAY, FileInfo(), ...)
end
function _MEM_ALARM_F(fmt, ...)
	local msg = sformat(fmt, ...)
	if logStdin then
		local context = _mem_context(FileInfo(), msg)
		_log_print(4, context)
	end
	local cfile = sformat("%s%s.log", _MEM_LOG_PATH, os_date("%Y%m%d"))
	LogToFile(cfile, LOG_LEVEL.WRITE_DELAY, FileInfo(), msg)
end

local function _L_LOGIC_ALARM(deep, ...)
	local cfile = _ERROR_A_ALARM_PATH .. os_date("error_%Y_%m_%d_%H.log", os.time())
	LogToFile(cfile, LOG_LEVEL.WRITE_DELAY, FileInfo(deep), ...)
end
-- _ERROR打印并且邮件报警（在我看来就是一个信息打印两种日志）
function _ERROR_ALARM(...)
	_L_LOGIC_ALARM(4, ...)
end
function _ERROR_A_ALARM(...)
	_L_LOGIC_ALARM(4, ...)
	if logStdin then
		local context = _error_context(FileInfo(), ...)
		_log_print(3, context)
	end
	_L_ERROR(4, ...)
end

-- 指定缓存文件名，记录信息！
local function _L_EVENT(deep, fileName, ...)
	local cfile = sformat(_LOG_EVENT_PATH, os_date("%Y%m%d"), fileName)
	LogToFile(cfile, LOG_LEVEL.WRITE_DELAY, FileInfo(deep), ...)
end
function _LOG_EVENT(fileName, ...)
	assert(fileName)
	if logStdin then
		local context = _log_event_context(FileInfo(), ...)
		_log_print(5, context)
	end
	_L_EVENT(4, fileName, ...)
end

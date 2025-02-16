local skynet = require "skynet"
local mysql = require "skynet.db,mysql"
local sharedata = require "skynet.sharedata"
local table = table
local string = string
local io = io
local pcall = pcall
local type = type
local pairs = pairs
local ipairs = ipairs
local assert = assert
local tostring = tostring
local error = error
local stringrep = string.rep
local stringgub = string.gsub
local tconcat = table.concat
local os_date = os.date
local sformat = string.format
local io_open = io.open

dofile "base/extend.lua"

local is_testserver = (skynet.getenv("is_testserver") == "true") and true or false
local PROFILE_CMD = Import("global/profile_cmd.lua")
local LOGDB_CFG = assert(load("return " .. skynet.getenv("logdb_info"))())
local LOG = Import("base/log.lua")

local PROXYSVR = Import("base/proxysvr.lua")
local SHUTDOWN_SVR = PROXYSVR.GetProxyByServiceName("shutdown")
local SNODE_NAME = DPCLUSTER_NODE.self

local LOG_DIRNAME = skynet.getenv("log_dirname" ) or skynet.getenv("node")
assert(LOG_DIRNAME)
local DATABASE_BASEDIR = nil
if LOG_DIRNAME then
    DATABASE_BASEDIR = "../log/" .. LOG_DIRNAME "/loginfile/"
else
    DATABASE_BASEDIR = "../log/unknow/loginfile/"
end
local ErrorStr = "badresult"
local SQL_FORMAT = "INSERT INTO %s(timestamp,%s) VALUES"
local FLUSH_TODB_SECTIME = 5 * 100

sort_logdata_xls = false
DB_OBJ = false

-- {
-- 	[fileName] = true,
-- 	...
-- }
ERROR_FILE = {}		-- 存数据库失败的

-- {
-- 	[timeStr] = {[tableName] = fb, ...}
-- }
FILE_HANDLER = {}

-- {
-- 	[tableName] = first_sql,
-- 	...
-- }
TABLE_DES = {}

Invalid = false
local function GetDbInvalid()
	return Invalid
end
local function SetDbInvalid(inv)
	Invalid = inv
end

function RESPONSE.closedb()
	if GetDbInvalid() then return end			-- 已经设置停服
	SetDbInvalid(true)
	-- 把所有数据都存盘了先
	TryCall(FlushToDatabase, true)
	return true
end

function ACCEPT.log2db(tblName, data)
	if GetDbInvalid() then return end

	local d = os_date("*f")
	local tkey = sformat("%04d%02d%02d%02d%02d", d.year, d.month, d.day, d.hour, d.min)
	local fHandlers = FILE_HANDLER[tkey]
	if not fHandlers then
		fHandlers = {}
		FILE_HANDLER[tkey] = fHandlers
    end
    local fileName = sformat("%s%s%s.log", DATABASE_BASEDIR, tblName, tkey)
    local fh = fHandlers[fileName]
    local isFirstOpen = false
    if not fh then
		posix.mkdir_p(fileName)
		fh = io_open(fileName, "w+")
		if not fh then
			local msg = sformat("log2db can not open file:%s data:%s", fileName, data)
			error(msg)
		end
		fHandlers[fileName] = fh
		fh:write(TABLE_DES[tblName])
		isFirstOpen = true
	end

	if isFirstOpen then
		fh:write("(")
	else
		fh:write(",(")
    end
	fh:write(sformat("\"%04d-%02d-%02d %02d:%02d:%02d \",", d.year, d.month, d.day, d.hour, d.min, d.sec))
	fh:write(data)
	fh:write(")")
	fh:flush()
end

function ACCEPT.batch_log2db(tblName, dlist)
	for _, _data in ipairs(dlist) do
		ACCEPT.log2db(tblName, _data)
	end
end

function ModifyTableDes(new_xls)
    for _tblName, _data in pairs(new_xls) do
		TABLE_DES[_tblName] = sformat(SQL_FORMAT, _tblName, tconcat(_data, ","))
	end
end

function ACCEPT.loadxls_finish()
	-- 没有 sort_logdata_xls 则 sharedata 无法获取环境变量
    sort_logdata_xls = sharedata.query("SortLogData", "ModifyTableDes")
end

local function _FlushErrFileToDatabase()
	for _fileName, _ in pairs(ERROR_FILE) do
		local rFh = io_open(_fileName, "r")
		if not rFh then
			local msg = sformat("FlushErrFileToDatabase can not open file:%s", _fileName)
			error(msg)
		end
		local sql = rFh:read("*a")
		rFh:close()
		local isOk, res = pcall(DB_OBJ.query, DB_OBJ, sql)
		if not isOk or res[ErrorStr] then
			local msg = sformat("FlushErrFileToDatabase flush file:%s to database error, res:%s", _fileName, tool.dump(res))
			LOG._ERROF(msg)
		else
			ERROR_FILE[_fileName] = nil
			-- 成功入库则删除文件
			local ok, err = os.remove(_fileName)
			if not ok then
				local msg = sformat("FlushErrFileToDatabase remove file:%s error:%s", _fileName, tool.dump(res))
				error(msg)
			end
		end
	end
end

function ACCEPT.flusherrfile2db()
	_FlushErrFileToDatabase()
end

function ACCEPT.flushallfile2db()
	FlushToDatabase(true)
end

function FlushToDatabase(flushAll)
	pcall(DB_OBJ.query, DB_OBJ, "desc nodule;")			-- 以防断开了
	local d = os_date("*t")
	local tkey = sformat("%04d%02d%02d%02d%02d", d.year, d.month, d.day, d.hour, d.min)
	local flushData = {}
	for _tkey, _fHandlers in pairs(FILE_HANDLER) do
		if flushAll or _tkey ~= tkey then
			flushData[_tkey] = _fHandlers
			FILE_HANDLER[_tkey] = nil
		end
	end
	for tkey, _fHandlers in pairs(flushData) do
		for _fileName, _fh in pairs(_fHandlers) do
			_fh:close()
			local rFh = io_open(_fileName, "r")
			if not rFh then
				local msg = sformat("FlushToDatabase can not open file:%s", _fileName)
				error(msg)
			end
			local sql = rFh:read("*a")
			rFh:close()
			local isOk, res = pcall(DB_OBJ.query, DB_OBJ, sql)
			if not isOk or res[ErrorStr] then
				local msg = sformat("FlushToDatabase flush file:%s to database error, res:%s", _fileName, tool.dump(res))
				LOG._ERROR(msg)
				ERROR_FILE[_fileName] = true
			else
				-- 成功入库则删除文件
				local ok, err = os.remove(_fileName)
				if not ok then
					local msg = sformat("FlushToDatabase remove file:%s error:%s", _fileName, err)
    				error(msg)
    			end
    		end
    	end
	end
    if flushAll then
		_FlushErrFileToDatabase()
	end
end

local function _StartUpCheckPath(path)
	if not posix.stat(path) then return end
	for file in posix.files(path) do
		if file ~= "." and file ~= ".." and file ~= ".svn" and file ~= ".git" then
			local pathFile = path .. "/" .. file
			local fileType = posix.stat(pathFile).type
			if fileType == "directory" then		-- 目录
				_StartUpCheckPath(pathFile)
			elseif fileType == "regular" then 	-- 文件
				local rFh = io_open(pathFile, "r")
				if not rFh then
					local msg = sformat("_StartUpCheckPath can not open file:%s", pathFile)
					error(msg)
				end
				local sql = rFh:read("*a")
				rFh:close()

				local isOk, res = pcall(DB_OBJ.query, DB_OBJ, sql)
				if not isOk or res[ErrorStr] then
					local msg = sformat("_StartUpCheckPath Flush file:%s to database error, res:%s", pathFile, tool.dump(res))
					skynet.error(msg)		-- 还没启动 gamelog 服务，所以不能用 LOG._ERROR
				else
					-- 成功入库则删除文件
					local ok, err = os.remove(pathFile)
					if not ok then
						local msg = sformat("_StartUpCheckPath remove file:%s error:%s", pathFile, err)
						error(msg)
					end
				end
			else
				local msg = sformat("_StartUpCheckPath check file:%s, fileType:%s error", pathFile, fileType)
				skynet.error(msg)           -- 还没启动 gamelog 服务，所以不能用 LOG._ERROR
            end
        end
    end
end

local function DealwithTimer()
	while true do
		skynet.sleep(30000)			-- 5 分钟一个心跳包
		if not GetDbInvalid() then
			pcall(DB_OBJ.query, DB_OBJ, "desc module;")
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
		db:query("set charset utf8")
	end
	DB_OBJ = mysql.connect{
		host = LOGDB_CFG.dbhost,
		port = LOGDB_CFG.dbport,
		database = LOGDB_CFG.dbname,
		user = LOGDB_CFG.dbuser,
		password = LOGDB_CFG.dbpasswd,
		max_packet_size = 1024 * 1024 * 2^9 - 1,	-- 无用设置
		on_connect = on_connect,
	}
	-- 询问query的时候如果是断开快开始会继续链接，知道连接上
	if not DB_OBJ then
		error("connect mysql error!")
	end
	skynet.timeout(0, DealwithTimer)
	skynet.fork(function ()
		while true do
			skynet.sleep(FLUSH_TODB_SECTIME)
			TryCall(DBINFILE.FlushToDatabase)	-- 必须带有DBINFILE才能达到可热更
		end
	end)

	-- 启动检测是否有没有入库的日志
	_StartUpCheckPath(DATABASE_BASEDIR)
end
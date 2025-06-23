local skynet = require "skynet"
local posix = require "posix"
local string = string
local table = table
local tinsert = table.insert
local selfnode_name = DPCLUSTER_NODE.node_ipport

-- 执行命令：wget -q -O - "http://127.0.0.1:40001/hot_update"

-- 热更新的具体逻辑
-- 	热更新后必须保证两个事情：
-- 		1.function env不会改变，因为有大量的逻辑是以来与fenv的，比如callout等
--		2.module里面的table的引用继续有效，并且能够及时更新到
--
-- 	面向对象处理：
--		类模板和对象，对象本质上就是一堆持久化和非持久化的数据，并附加一个元表实现的。
--		所有，在热更新的时候只需要更新类的模板，并将最新的table和旧的table进行比对，进而修改旧的table即可。

--	模块方法处理：
--		使用loadfile加载，每个模块都有特定的env。所有热更新后得到的新的env和旧的env进行比对，并修改旧的env。
--
--	此外，热更新若想新增一个模块则需要在旧的模块中使用Import。而不是在热更新中新增全新未加载的模块

TOOL_FILEMTIME = {}	-- 工具库文件的最近一次修改时间
MACRO_FILETIME = {}	-- 常量文件的最近一次修改时间
GAME_FILEMTIME = {}	-- game目录下的文件最近一次修改时间

local function _ReadFile(path, result, deep)
	deep = (deep or 0) + 1
	if deep > 50 then
		skynet.error(path .. " directory too much deep")
	end

	result = result or {}
	path = path or "game"
	for file in posix.files(path) do
		if file ~= "." and file ~= ".." and file ~= ".git" and file ~= ".svn" then
			file = path .. "/" .. file
			local t = posix.stat(file) or {}
			if t.type == "directory" then				-- 目录
				_ReadFile(file, result, deep)
			elseif t.type == "regular" then				-- 文件
				if string.endswith(file, ".lua") then
					result[file] = t.mtime
				end
			else
				skynet.error("error file type " .. file)
			end
		end
	end
	return result
end

local function _GetFileMtimes()
	local fileMtimes1 = _ReadFile()
	local fileMtimes2 = _ReadFile("tool/luaplugins")
	local t1, t2, t3 = {}, {}, {}
	local function func(fileMtimes)
		for fileName, mtime in pairs(fileMtimes) do
			if table.has_value(TOOL_FILES, fileName) then
				-- lua原生函数拓展文件
				t1[fileName] = mtime
			elseif table.has_value(MACRO_FILES, fileName) then
				-- 常量文件
				t2[fileName] = mtime
			elseif string.beginswith(fileName, "game/") then
				-- game目录下的逻辑文件
				t3[fileName] = mtime
			end
		end
	end
	func(fileMtimes1)
	func(fileMtimes2)
	return t1, t2, t3
end

-- 热更新逻辑处理
function Handle_Request(data)
	local nTOOL_FILEMTIME, nMACRO_FILETIME, nGAME_FILEMTIME = _GetFileMtimes()

	-- 收集有改动的代码文件
	local UPDATE_TYPE = UPDATE_TYPE or {TOOL = 1, MACROS = 2, IMPORT = 3}
	local updateFiles = {
		[UPDATE_TYPE.TOOL] = {},
		[UPDATE_TYPE.MACROS] = {},
		[UPDATE_TYPE.IMPORT] = {},
	}
	for pathFile, mtime in pairs(nTOOL_FILEMTIME) do
		if TOOL_FILEMTIME[pathFile] and mtime > TOOL_FILEMTIME[pathFile] then
			tinsert(updateFiles[UPDATE_TYPE.TOOL], pathFile)
		end
	end
	for pathFile, mtime in pairs(nMACRO_FILETIME) do
		if MACRO_FILETIME[pathFile] and mtime > MACRO_FILETIME[pathFile] then
			tinsert(updateFiles[UPDATE_TYPE.MACROS], pathFile)
		end
	end
	for pathFile, mtime in pairs(nGAME_FILEMTIME) do
		if GAME_FILEMTIME[pathFile] and mtime > GAME_FILEMTIME[pathFile] then
			tinsert(updateFiles[UPDATE_TYPE.IMPORT], pathFile)
		end
	end

	if table.empty(updateFiles[UPDATE_TYPE.TOOL]) and
		table.empty(updateFiles[UPDATE_TYPE.MACROS]) and
		table.empty(updateFiles[UPDATE_TYPE.IMPORT])
	then
		_WARN("not code hot update!")
		return true
	end

	local PROXYSVR = Import("game/global/proxysvr.lua")
	local lsvr = PROXYSVR.GetProxy(".launcher", selfnode_name)
	if lsvr.call.UPDATE_FILES(updateFiles) then
		TOOL_FILEMTIME = nTOOL_FILEMTIME
		MACRO_FILETIME = nMACRO_FILETIME
		GAME_FILEMTIME = nGAME_FILEMTIME
	end

	return true
end

function __init__()
	TOOL_FILEMTIME, MACRO_FILETIME, GAME_FILEMTIME = _GetFileMtimes()
end

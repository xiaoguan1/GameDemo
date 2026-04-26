local string = string
local sformat = string.format
local io = io
local iopen = io.open
local ipopen = io.popen

local protocolPath = "./protocol/"
local fileProtoPath = protocolPath .. "protos"
local pbsPath = protocolPath .. "pbs"

local protoc = "protoc --proto_path=" .. fileProtoPath .. " -o "
local protocTail = "/%s.pb %s"
local protocHead = protoc .. pbsPath

local function _Error(fmt, ...)
	if (...) == nil then
		error(fmt)
	else
		error(sformat(fmt, ...))
	end
end

-- 字符串切割
function string.split(str, sep)
	if not sep or not str or str == "" then
		return
	end
	local result = {}
	for s in str:gmatch("([^" .. sep .. "]+)") do
		table.insert(result, s)
	end
	return result
end

-- 检查 .proto 文件内容 
local function _GetProtoFiles()
	local dirs = assert(ipopen("ls " .. fileProtoPath),
							sformat("%s popen fail!", fileProtoPath))

	local result = {}
	for file in dirs:lines() do
		local fPath = fileProtoPath .. "/" .. file
		local f = assert(iopen(fileProtoPath .. "/" .. file),
					sformat("filePath:%s open fail!", fPath))

		local context, err = f:read("*a")
		f:close()
		if not context then
			_Error("%s err:%s", file, err)
		end

		local fileName = string.split(file, ".")
		fileName = assert(fileName and fileName[1],
						sformat("%s not find file name", file))

		-- 判断是否定义了 syntax = "proto2";
		local sIdx, _eIdx = context:find('syntax%s*=%s*\"proto2\"%s*;')
		if not sIdx then
			_Error("%s must set syntax = proto2;", file)
		end

		-- 判断是否定义了package
		local sIdx, _eIdx = context:find("package%s+" .. fileName .. "%s*;")
		if not sIdx then
			_Error("%s must set package %s;", file, fileName)
		end

		table.insert(result, file)
	end
	dirs:close()
	return result
end

-- protoc 编译 .proto 文件
local function _Make()
	local fileList = _GetProtoFiles()
	if not fileList or #fileList <= 0 then
		return
	end

	-- 删除pb文件夹下的所有文件
	os.execute("rm -rf " .. pbsPath .. "/*")

	for _, file in pairs(fileList) do
		local fileName = string.split(file, ".")
		fileName = assert(fileName and fileName[1],
						sformat("%s not find file name", file))

		local tail = sformat(protocTail, fileName, file)
		os.execute(protocHead .. tail)
		print(sformat("protoc make succeed %s", tail))
	end
end

_Make()
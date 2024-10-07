local protocolPath = "./../protocol/"
local fileProtoPath = protocolPath .. "proto"
local pbPath = protocolPath .. "pb"

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
local function _CheckProtoFile()
	local dirInfo = io.popen("ls " .. fileProtoPath)
	local result = {}
	for file in dirInfo:lines() do
		local filePath = fileProtoPath .. "/" .. file
		local f = io.open(filePath)
		local fileContext, err = f:read("*a")
		if not fileContext then
			error(string.format("%s err:%s", file, err))
		end

		local fileName = string.split(file, ".")
		fileName = fileName and fileName[1]
		if not fileName then
			error(string.format("%s not find file name", file))
		end

		-- 判断是否定义了 syntax = "proto2";
		local sIdx, eIdx = fileContext:find('syntax%s*=%s*\"proto2\"%s*;')
		if not sIdx then
			error(string.format("%s must set syntax = proto2;", file))
		end

		-- 判断是否定义了package
		local sIdx, eIdx = fileContext:find("package%s+" .. fileName .. "%s*;")
		if not sIdx then
			error(string.format("%s must set package %s;", file, fileName))
		end

		table.insert(result, file)
	end
	dirInfo:close()
	return result
end

-- protoc 编译 .proto 文件
local function _MakeProtoFile()
	local fileList = _CheckProtoFile()
	if not fileList or #fileList <= 0 then
		return
	end

	-- 删除pb文件夹下的所有文件
	os.execute("rm -rf " .. pbPath .. "/*")

	local pCmd = "protoc --proto_path=" .. fileProtoPath .. " -o "
	for _, file in pairs(fileList) do
		local fileName = string.split(file, ".")
		fileName = fileName and fileName[1]
		if not fileName then
			error(string.format("%s not find file name", file))
		end

		local fCmd = pbPath .. "/" .. fileName .. ".pb " .. file
		os.execute(pCmd .. fCmd)
	end
end
_MakeProtoFile()
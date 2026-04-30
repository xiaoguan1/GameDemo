--[[
编译协议的主要流程
	流程1 使用protoc对proto文件进行编译生成pb文件
	
	流程2 生成协议信息
		1.game/global/rprotomap.lua 是业务开发定义的协议信息
		2.protocol/auto-generate-rprotomap.lua 和 protocol/record-protocol-id 是自动化生成的协议文件，不允许手动修改！！！
		3.节点内，其实加载的是auto-generate-rprotomap.lua文件

	注意：目前protobuf仅支持版本2，未支持版本3
]]

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

local TipMsg = "----- auto generate file, please do not modify -----"
local SPI_normal = false	-- save-prot-id文件默认状态异常（即覆盖的方式写入）
local maxProtId
local protName2Id = {}
local function _ReadSaveProtId(filePath)
	local f = io.open(filePath, "r")
	if not f then
		-- 文件不存在，则创建并初始化
		print("create " .. filePath)
		f = io.open(filePath, "a+")
		if not f then
			_Error("%s io open fail", filePathi)
		end
		f:write(TipMsg)
		maxProtId, SPI_normal = 1, true
		return
	end

	local lineNo = 1
	for c in f:lines() do
		if lineNo == 1 then
			if c == TipMsg then
				-- save-prot-id文件正常，尾部追加方式写入
				SPI_normal = true
			end
		else
			local protName, protId = string.match(c, "%s*(.*)%s*,%s*(%d*)%s*")
			protId = protId and tonumber(protId)
			if protName and protId then
				if protId > 65536 then
					-- 因为协议编号仅占用2个字节，故范围在1到65536的协议编号
					-- 若超出该范围则需要考虑业务那边是否需要拓展
					_Error("protocol id > 65536!!!")
				end
				protName2Id[protName] = protId
				if not maxProtId or protId > maxProtId then
					maxProtId = protId
				end
			else
				-- 存在某一行的内容格式不正确
				SPI_normal = false
				print(c)
			end
		end
		lineNo = lineNo + 1
	end

	-- 若空，则默认值为1
	maxProtId = maxProtId or 1
end
_ReadSaveProtId("protocol/save-prot-id")



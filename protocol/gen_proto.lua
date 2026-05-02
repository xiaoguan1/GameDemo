--[[
编译协议的主要流程
	流程1 使用protoc对proto文件进行编译生成pb文件
	
	流程2 生成协议信息
		1.game/global/rprotomap.lua 是业务开发定义的协议信息
		2.protocol/auto-generate-rprotomap.lua 和 protocol/record-protocol-id 是自动化生成的协议文件，不允许手动修改！！！
		3.节点内，其实加载的是auto-generate-rprotomap.lua文件

	注意：目前protobuf仅支持版本2，未支持版本3
]]

local table = table
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

local proFiles = {}			-- proto后缀的协议文件
local package2message = {}	-- proto后缀文件的message内容

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

function table.size(t)
	assert(t)
	local count = 0
	for _ in pairs(t) do
		count = count +1
	end
	return count
end

-- 检查 .proto 文件内容 
local function _GetProtoFiles()
	local dirs = assert(ipopen("ls " .. fileProtoPath),
							sformat("%s popen fail!", fileProtoPath))

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
		local isSyntax = context:find("syntax%s*=%s*\"proto2\"%s*;")
		if not isSyntax then
			_Error("%s must set syntax = proto2;", file)
		end

		-- 判断是否定义了package
		local isPackage = context:find("package%s+" .. fileName .. "%s*;")
		if not isPackage then
			_Error("%s must set package %s;", file, fileName)
		end

		table.insert(proFiles, file)

		if package2message[fileName] then
			-- 重复定义了 package 相同的名字
			_Error("%s repeat package %s", file, fileName)
		else
			local messageList = {}
			package2message[fileName] = messageList
			for message in context:gmatch("%s*message%s+([%w_]+)") do
				if messageList[message] then
					_Error("%s repeat message %s", fileName, message)
				end
				messageList[message] = true
			end
		end
	end
	dirs:close()
end

-- protoc 编译 .proto 文件
local function _MakePbs()
	_GetProtoFiles()
	if #proFiles <= 0 then
		return
	end

	-- 删除pb文件夹下的所有文件
	os.execute("rm -rf " .. pbsPath .. "/*")

	for _, file in pairs(proFiles) do
		local fileName = string.split(file, ".")
		fileName = assert(fileName and fileName[1],
						sformat("%s not find file name", file))

		local tail = sformat(protocTail, fileName, file)
		os.execute(protocHead .. tail)
		print("protoc make " .. file)
	end
end

local TipMsg = "----- auto generate file, please do not modify -----"
local Spi_Is_Cover = true	-- save-prot-id文件默认为覆盖写入
local MAXPROTID = 65536		-- 最大允许的协议编号
local addProtocol = 0		-- 新增协议数量
local nowProtId				-- 当前协议编号
local protName2Id, id2ProtoName = {}, {}
local saveprotid_path = "protocol/save-prot-id"
local function _LoadSaveProtId()
	local f = iopen(saveprotid_path, "r")
	if not f then
		-- 文件不存在，则创建并初始化
		print("create " .. saveprotid_path)
		os.execute(sformat("rm -f %s ; touch %s", saveprotid_path, saveprotid_path))
		nowProtId = 0
		return
	end

	local lineNo = 1
	for c in f:lines() do
		if lineNo == 1 then
			if c == TipMsg then
				-- save-prot-id文件正常，尾部追加方式写入
				Spi_Is_Cover = false
			end
		else
			local protName, protId = string.match(c, "%s*(.*)%s*,%s*(%d*)%s*")
			protId = protId and tonumber(protId)
			if protName and protId then
				if protId > MAXPROTID then
					-- 因为协议编号仅占用2个字节，故范围在1到65536的协议编号
					-- 若超出该范围则需要考虑业务那边是否需要拓展
					_Error("protocol id > %s!!!", MAXPROTID)
				end

				-- 协议编号的自增检查（必须是以1为增值）
				local isOk
				if (not nowProtId and protId == 1) or
					(nowProtId and (protId - nowProtId) == 1)
				then
					isOk = true
				end
				if not isOk then
					_Error("protocol id error, nowProtId:[%s] -> protId:[%s]", nowProtId or 0, protId)
				end

				protName2Id[protName] = protId
				id2ProtoName[protId] = protName
				nowProtId = protId
			else
				-- 存在某一行的内容格式不正确,直接报错处理.
				-- 即使不报错,接下来的协议编号检查也依然会抛出错误中断
				_Error("save-prot-id context error, [%s]", c)
			end
		end
		lineNo = lineNo + 1
	end
	f:close()

	-- 若空，则默认值为1
	nowProtId = nowProtId or 0
end

local PROT_TYPE_PUSH = "push"			-- 服务器推送协议（S->C）
local PROT_TYPE_NOTIFY = "notify"		-- 客户端推送协议（C->S）
local PROT_TYPE_RESPONSE = "response"	-- 前后端正常响应协议（C->S、S->C）
local rprotomap_path = "game/global/rprotomap.lua"
local function _LoadRprotomap()
	dofile(rprotomap_path)
	assert(RPROTOMAP and type(RPROTOMAP) == "table", "rprotomap.lua RPROTOMAP error")
	for protName, protBody in pairs(RPROTOMAP) do
		if not protBody.desc or #protBody.desc <= 0 or #protBody.desc >= 1024 then
			-- 没有定义desc 或者 desc太长
			_Error("rprotomap.lua %s desc error!", protName)
		end

		if protBody.type then
			-- 不能定义type，由该脚本自动判断类型
			_Error("rprotomap.lua %s must not definition type", protName)
		end

		if protBody.request and protBody.response then
			protBody.type = PROT_TYPE_RESPONSE
		elseif protBody.request then
			protBody.type = PROT_TYPE_NOTIFY
		elseif protBody.response then
			protBody.type = PROT_TYPE_PUSH
		else
			_Error("rprotomap.lua %s not definition request or response", protName)
		end

		-- 检查 request 和 response 的合法性
		for k, v in pairs({request = protBody.request, response = protBody.response}) do
			local isOk
			local info = string.split(v, ".") or {}
			if #info == 2 then
				local package = info[1]
				local message = info[2]
				if package2message[package] and package2message[package][message] then
					isOk = true
				end
			end
			if not isOk then
				_Error("rprotomap.lua %s, %s message not exist", protName, k)
			end
		end

		-- 赋值协议编号
		protBody.id = protName2Id[protName]
		if not protBody.id then
			-- 新增协议
			addProtocol = addProtocol + 1
			protBody.id = nowProtId + addProtocol
			protName2Id[protName] = protBody.id
			id2ProtoName[protBody.id] = protName
		end
	end
end

local function _WriteSaveSpi()
	local startId, endId, mode
	if Spi_Is_Cover then
		-- 覆盖写
		mode = "w+"
		startId = 1
		endId = nowProtId + addProtocol
	else
		-- 追加写
		if addProtocol <= 0 then
			-- 没有新增协议，则无写入处理
			return
		end
		mode = "a+"
		startId = nowProtId + 1
		endId = nowProtId + addProtocol
	end

	local f = iopen(saveprotid_path, mode)
	if not f then
		_Error("%s io open fail", saveprotid_path)
	end

	if Spi_Is_Cover then
		-- 覆盖写
		f:write(TipMsg .. "\n")
	end

	for id = startId, endId do
		f:write(sformat("%s,%s\n", id2ProtoName[id], id))
	end

	f:flush()
	f:close()
end

local protomap_path = "protocol/protomap.lua"
local function _WriteProtomap()
	local f = iopen(protomap_path, "w+")
	if not f then
		_Error("%s io open fail", protomap_path)
	end
	f:write(TipMsg .. "\n")
	f:write("PROTOMAP = {\n")

	local bodyFmt1 = [[
	["%s"] = { desc = "%s", type = "%s", id = "%s",
		response = "%s",
	},
]]
	local bodyFmt2 = [[
	["%s"] = { desc = "%s", type = "%s", id = "%s",
		request = "%s",
	},
]]
	local bodyFmt3 = [[
	["%s"] = { desc = "%s", type = "%s", id = "%s",
		request = "%s",
		response = "%s",
	},
]]

	local writeCount = 0
	for id = 1, nowProtId + addProtocol do
		local protName = assert(id2ProtoName[id])
		local protBody = RPROTOMAP[protName]
		if protBody then
			local bodyContext
			if protBody.type == PROT_TYPE_PUSH then
				bodyContext = sformat(bodyFmt1, protName, protBody.desc, PROT_TYPE_PUSH, id, protBody.response)
			elseif protBody.type == PROT_TYPE_NOTIFY then
				bodyContext = sformat(bodyFmt2, protName, protBody.desc, PROT_TYPE_NOTIFY, id, protBody.request)
			else
				bodyContext = sformat(bodyFmt3, protName, protBody.desc, PROT_TYPE_RESPONSE, id, protBody.request, protBody.response)
			end
			f:write(bodyContext)
			writeCount = writeCount + 1
		end
	end
	f:write("}")
	f:flush()
	f:close()

	dofile(protomap_path)
	local protomap_len = table.size(PROTOMAP)
	if protomap_len ~= writeCount then
		_Error("auto-generate %s, unknown error!", protomap_path)
	end
end

---------------- 生成协议信息 ----------------
_MakePbs()
_LoadSaveProtId()
_LoadRprotomap()
_WriteSaveSpi()
_WriteProtomap()
print("---------- make protocol all finish ----------")

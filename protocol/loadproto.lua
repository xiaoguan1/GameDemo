-----------------------------
--- 加载协议 和 更新协议
-----------------------------
local skynet = require "skynet"
local c = require "protobuf.c"
local posix = require "posix"
local pstat = posix.stat
local utilc = require "util.core"
local protobuf = require "protobuf"
local error = error
local string = string
local sformat = string.format

local _ERROR_F = _ERROR_F
local SERVICE_NAME = SERVICE_NAME
local selfnode_name = DPCLUSTER_NODE.node_ipport

-- 需要预先加载协议文件，因为有些porto需要import其他协议文件
local preload_load = {
}

-- 记录已加载的协议文件
ALREADY_LOAD_PBS = {
}

local function _AllPbFiles()
	local pbfiles = posix.scandir("protocol/pbs", {ftype = ".pb"})
	local result = {}
	for file in pairs(pbfiles) do
		local fstat = pstat(file)
		if fstat then
			result[file] = fstat.mtime
		else
			error("error pb file " .. file)
		end
	end
	return result
end

-- 加载协议
function LoadProto()
	local P = protobuf.P
	if not P then
		_ERROR_F("SERVICE_NAME:%s not P!", SERVICE_NAME)
		return
	end

	local filesMtime = _AllPbFiles()
	if not next(filesMtime or {}) then
		_ERROR_F("./protocol/pbs none pb files")
		return
	end

	-- 先预先加载协议文件
	for _, filename in ipairs(preload_load) do
		local mtime = filesMtime[filename]
		if not mtime then
			error("error pb file " .. filename)
		end
		protobuf.register_file(filename)
		ALREADY_LOAD_PBS[filename] = mtime
	end

	for filename, mtime in pairs(filesMtime) do
		if not ALREADY_LOAD_PBS[filename] then
			protobuf.register_file(filename)
			ALREADY_LOAD_PBS[filename] = mtime
		end
	end

	-- 不返回true，会导致起服失败！
	return true
end

-- 热更新协议
function command.update(isUpdateProto)
	if not isUpdateProto then
		return
	end

	local PROXYSVR = Import("game/global/proxysvr.lua")
	local lsvr = PROXYSVR.GetProxy(".launcher", selfnode_name)
	if not lsvr then
		_ERROR("proto hot update fail, because .launcher svr not exists!")
		return true
	end

	-- 流程1：创建新P，并把所有的pb文件进行注册处理
	local newP = c._env_new()
	local filesMtime = _AllPbFiles()
	for filename, mtime in pairs(filesMtime) do
		local oMtime = ALREADY_LOAD_PBS[filename]
		if not oMtime or mtime > oMtime then
			skynet.error(sformat("----- %s update -----", filename))
		end
		protobuf.register_file(filename)
	end

	-- 流程2：挂载最新的P
	utilc.add_pbenv(newP)
	utilc.load_pbenv()

	-- 通知所有服务进行协议更新
	local OldP, OldGC = protobuf.P, protobuf.GC
	if not lsvr.call.UPDATE_PROTO() then
		-- 其他服务更新失败,恢复原来的数据.
		c.pbc_delete(newP)
		utilc.add_pbenv(OldP)
		utilc.load_pbenv()

		_ERROR_F("%s update proto fail", SERVICE_NAME)
		return
	end

	-- 把本节点的protobuf.lua中的P和GC进行切换
	protobuf.P = debug.getregistry().PROTOBUF_ENV
	protobuf.GC = c._gc()
	protobuf.update_pgc()
	c._gc_load_env(OldGC, OldP)

	-- 置空,否则这一帧会gc不掉(当然后续会gc它，但个人倾向于这一帧gc掉它).
	OldP, OldGC = nil, nil
	collectgarbage()

	return true
end

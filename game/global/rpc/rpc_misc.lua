local skynet = require "skynet"
local node = SELF_NODE.node				-- 节点类型名称
local GCLUSTER_NODE = SELF_NODE			-- 节点配置
local SELF_IPPORT = SELF_IPPORT			-- 自己节点的网络地址
local BASIC_SERVICE_MAP = BASIC_SERVICE_MAP

local is_testserver = (skynet.getenv("is_testserver") == "true") and true or false

local assert = assert
local type = type
local pairs = pairs
local xpcall = xpcall
local traceback = debug.traceback
local error = error
local getmetatable = getmetatable
local select = select
local string = string
local sformat = string.format

local OVERTIME = 	300 	-- 3秒
local MAX_OVERTIME = 600 	-- 6秒

GCLUSTER_ADDR = false

local function getClusterAddr()
	if GCLUSTER_ADDR then
		return GCLUSTER_ADDR
	end
	local named = BASIC_SERVICE_MAP["gcluster"].named
	GCLUSTER_ADDR = skynet.localname(named)
	return GCLUSTER_ADDR
end

-- 结果检查，不支持userdata作为返回结果！
local function _ret_func(msg, sz, ok, ...)
	skynet.trash(msg, sz)	-- 释放内存
	if not ok then
		error((...))
	end

	if is_testserver then
		for _n, _v in pairs({...}) do
			if type(_v) == "userdata" then
				error("dpcluster ret has point error!")
			end
		end
	end
	return ...
end

local function __call(overtime, node, address, prototype, ...)
	-- skynet.error("--__call:", overtime, node, address, prototype, ...)
	-- ...不能有userdata, 判断一下
	for _n, _v in pairs({...}) do
		if type(_v) == "userdata" then
			error(sformat("node:%s, address:%s, elem no:%d is userdata", node, address, _n))
		end
	end

	local pack_func = skynet.get_prototype_pack(prototype)
	local unpack_func = skynet.get_prototype_unpack(prototype)
	assert(pack_func and unpack_func)

	local gclusterd = assert(getClusterAddr())
	local msg, sz = skynet.call(gclusterd, "lua", "req", overtime, node, address, prototype, pack_func(...)) -- 肯定是当前节点，所以不用代理了
	return _ret_func(msg, sz, xpcall(unpack_func, traceback, msg, sz))
end

local function __send(node, address, prototype, ...)
	-- skynet.error("--__send:", overtime, node, address, prototype, ...)
	-- ...不能有userdata, 判断一下
	for _n, _v in pairs({...}) do
		if type(_v) == "userdata" then
			error(sformat("node:%s, address:%s, elem no:%d is userdata", node, address, _n))
		end
	end

	local pack_func = assert(skynet.get_prototype_pack(prototype))
	local gclusterd = assert(getClusterAddr())
	skynet.send(gclusterd, "lua", "push", node, address, prototype, pack_func(...)) -- 肯定是当前节点，所以不用代理了
end

-- 不允许无限时长等待
function call_o(overtime, node, address, ...)
	assert(overtime >= OVERTIME and overtime <= MAX_OVERTIME)
	return __call(overtime, node, address, ...)
end

function call(node, address, ...)
	return __call(OVERTIME, node, address, ...)
end

-- 异步跨节点发消息
function send(node, address, ...)
	__send(node, address, ...)
end
--------------------
-- 模块作用：服务代理，替代skynet的send与call，拓展成不单单对当前节点的send与call
--------------------

local skynet = require "skynet"
local setmetatable = setmetatable
local assert = assert
local error = error
local type = type

local SELF_CLUSTERNAME = assert(SELF_CLUSTERNAME)
local SERVERID_CONFIG = SERVERID_CONFIG
local host_id = tonumber(assert(skynet.getenv("server_id")))
local host_node = SELF_NODE.node
local cluster_no = tonumber(assert(skynet.getenv("cluster_no")))
local NODE_IP_MAP = assert(NODE_IP_MAP)

local RPC_MISC = Import("game/global/rpc/rpc_misc.lua")

local skynet_send = skynet.send
local skynet_call = skynet.call
local READONLY_META = { __newindex = function () error("read only") end }

local is_testserver = (skynet.getenv("is_testserver") == "true") and true or false
local function _obj_check(...)
	if not is_testserver then
		return
	end
	local n = select("#", ...)
	local arg = {...}
	for i = 1, n do
		if type(arg[i]) == "table" then
			local mt = getmetatable(arg[i])
			if mt and mt.__ObjectType then	-- 是对象
				error("param can not be obj")
			end
		end
	end
end

ALL_PROXYSVR = {
	self_node = {},
	othernode = {},
	-- ....
}

local function gen_send(addr, clustername, prototype)
	prototype = prototype or "lua"
	if clustername == SELF_CLUSTERNAME then
		local addrtype = type(addr)
		local addr_num = nil
		local cache_func = {}
		return setmetatable({},  {
			__index = function (t, k)
				if addrtype == "string" then
					if not addr_num then
						addr_num = skynet.localname(addr)
						if not addr_num then error("not service by name" .. addr) end
					end
				else
					addr_num = addr
				end
				if not cache_func[k] then
					cache_func[k] = function(...)
						_obj_check(...)
						return skynet_send(addr_num, prototype, k, ...)		-- skynet.send那里有返回是否有那个节点的信息
					end
				end
				return cache_func[k]
			end,
			__call = function (t, ...)
				if addrtype == "string" then
					if not addr_num then
						addr_num = skynet.localname(addr)
						if not addr_num then error("not service by name" .. addr) end
					end
				else
					addr_num = addr
				end
				_obj_check(...)
				return skynet_send(addr_num, prototype, ...)				-- skynet.send那里有返回是否有那个节点的信息
			end
		})
	else
		if not string.match(clustername, CLUSTER_NAME_MATCH) then
			error("clustername fmt error: " .. clustername)
		end
		local cache_func = {}
		return setmetatable({}, {
			__index = function (t, k)
				if not cache_func[k] then
					cache_func[k] = function (...)
						_obj_check(...)
						return RPC_MISC.send(clustername, addr, prototype, k, ...)	-- skynet.send那里有返回是否有那个节点的信息
					end
				end
				return cache_func[k]
			end,
			__call = function (t, ...)
				_obj_check(...)
				return RPC_MISC.send(clustername, addr, prototype, ...)				-- skynet.send那里有返回是否有那个节点的信息
			end
		})
	end
end

local function gen_call(addr, clustername, prototype)
	prototype = prototype or "lua"
	if clustername == SELF_CLUSTERNAME then
		local addrtype = type(addr)
		local addr_num = nil
		local cache_func = {}
		return setmetatable({},  {
			__index = function (t, k)
				if addrtype == "string" then
					if not addr_num then
						addr_num = skynet.localname(addr)
						if not addr_num then error("not service by name" .. addr) end
					end
				else
					addr_num = addr
				end
				if not cache_func[k] then
					cache_func[k] = function(...)
						_obj_check(...)
						return skynet_call(addr_num, prototype, k, ...)		-- skynet.send那里有返回是否有那个节点的信息
					end
				end
				return cache_func[k]
			end,
			__call = function (t, ...)
				if addrtype == "string" then
					if not addr_num then
						addr_num = skynet.localname(addr)
						if not addr_num then error("not service by name" .. addr) end
					end
				else
					addr_num = addr
				end
				_obj_check(...)
				return skynet_call(addr_num, prototype, ...)				-- skynet.send那里有返回是否有那个节点的信息
			end
		})
	else
		if not string.match(clustername, CLUSTER_NAME_MATCH) then
			error("clustername fmt error: " .. clustername)
		end
		local cache_func = {}
		return setmetatable({}, {
			__index = function (t, k)
				if not cache_func[k] then
					cache_func[k] = function (...)
						_obj_check(...)
						return RPC_MISC.call(clustername, addr, prototype, k, ...)
					end
				end
				return cache_func[k]
			end,
			__call = function (t, ...)
				_obj_check(...)
				return RPC_MISC.call(clustername, addr, prototype, ...)
			end
		})
	end
end

local function create_proxysvr(addr, clustername, prototype)
	return setmetatable({
		addr = addr,
		clustername = clustername,
		prototype = prototype,

		send = gen_send(addr, clustername, prototype),
		call = gen_call(addr, clustername, prototype),
	}, READONLY_META)
end


-- 外部接口 ------------------------------
function GetProxy(addr, clustername, prototype)
	if clustername == SELF_CLUSTERNAME then
		-- 本服节点
		if ALL_PROXYSVR.self_node[addr] and ALL_PROXYSVR.self_node[addr].prototype == prototype then
			return ALL_PROXYSVR.self_node[addr]
		else
			local proxy = create_proxysvr(addr, clustername, prototype)
			ALL_PROXYSVR.self_node[addr] = proxy
			return proxy
		end
	else
		-- 跨服节点
		assert(clustername)
		local proxy = ALL_PROXYSVR.othernode[addr] and ALL_PROXYSVR.othernode[addr][clustername]
		if proxy and proxy.prototype == prototype then
			return proxy
		end
		proxy = create_proxysvr(addr, clustername, prototype)
		ALL_PROXYSVR.othernode[addr] = ALL_PROXYSVR.othernode[addr] or {}
		ALL_PROXYSVR.othernode[addr][clustername] = ALL_PROXYSVR.othernode[addr][clustername] or {}
		ALL_PROXYSVR.othernode[addr][clustername] = proxy
		return proxy
	end
end

ttt = true
-- 获取当前节点的服务代理
function GetProxyByServiceName(serviceName, ...)
	local count = select("#", ...)
	local hostnode, prototype, serverId = host_node, "lua", host_id -- 默认值
	if count == 1 then
		-- 1个参数
		prototype  = ...
	elseif count == 2 then
		-- 2个参数
		prototype, serverId = ...
	elseif count == 3 then
		-- 3个参数
		hostnode, prototype, serverId = ...
	end
	assert(hostnode and prototype and serverId)

	-- 目前仅仅支持同一个集群内进行消息发送
	if not (NODE_IP_MAP[hostnode] and NODE_IP_MAP[hostnode][serverId]) then
		_ERROR_F("%s %s not exists", hostnode, serverId)
		return
	end

	local clustername
	local namedData = BASIC_SERVICE_MAP[serviceName]

	if namedData then
		-- 基础服务
		clustername = string.format(CLUSTER_NAME_FMT, hostnode, cluster_no, serverId)
	else
		if hostnode == USER_NODE then
			namedData = USER_SERVICE_MAP[serviceName]
			if namedData then
				-- user节点的基础服务
				clustername = string.format(CLUSTER_NAME_FMT, hostnode, cluster_no, serverId)
			else
				namedData = ADHOC_SERVICE_MAP[serviceName]
			end
		elseif host_node == CROSS_NODE then
		else
			_ERROR_F("proxy unknown %s", hostnode)
			return
		end
	end

	local named = assert(namedData and namedData.named)
	return GetProxy(named, clustername, prototype)
end
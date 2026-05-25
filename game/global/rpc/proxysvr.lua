--------------------
-- 模块作用：服务代理，替代skynet的send与call，拓展成不单单对当前节点的send与call
--------------------

local skynet = require "skynet"
local setmetatable = setmetatable
local assert = assert
local error = error
local type = type

local SELF_IPPORT = assert(SELF_IPPORT)
local ALL_SERVERID_MAP = ALL_SERVERID_MAP
local host_id = tonumber(assert(skynet.getenv("server_id")))

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

local function gen_send(addr, nodeName, prototype)
	prototype = prototype or "lua"
	if nodeName == SELF_IPPORT then
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
		local cache_func = {}
		return setmetatable({}, {
			__index = function (t, k)
				if not cache_func[k] then
					cache_func[k] = function (...)
						_obj_check(...)
						return RPC_MISC.send(nodeName, addr, prototype, k, ...)	-- skynet.send那里有返回是否有那个节点的信息
					end
				end
				return cache_func[k]
			end,
			__call = function (t, ...)
				_obj_check(...)
				return RPC_MISC.send(nodeName, addr, prototype, ...)				-- skynet.send那里有返回是否有那个节点的信息
			end
		})
	end
end

local function gen_call(addr, nodeName, prototype)
	prototype = prototype or "lua"
	if nodeName == SELF_IPPORT then
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
		local host, port = string.match(nodeName, "([^:]+):(.*)$")
		if not host or not port then
			error("not math host:port " .. nodeName)
		end
		local cache_func = {}
		return setmetatable({}, {
			__index = function (t, k)
				if not cache_func[k] then
					cache_func[k] = function (...)
						_obj_check(...)
						return RPC_MISC.call(nodeName, addr, prototype, k, ...)
					end
				end
				return cache_func[k]
			end,
			__call = function (t, ...)
				_obj_check(...)
				return RPC_MISC.call(nodeName, addr, prototype, ...)
			end
		})
	end
end

local function create_proxysvr(addr, nodeName, prototype)
	return setmetatable({
		addr = addr,
		nodeName = nodeName,
		prototype = prototype,

		send = gen_send(addr, nodeName, prototype),
		call = gen_call(addr, nodeName, prototype),
	}, READONLY_META)
end


-- 外部接口 ------------------------------
function GetProxy(addr, node_name, prototype)
	if node_name == SELF_IPPORT then
		-- 本服节点
		if ALL_PROXYSVR.self_node[addr] and ALL_PROXYSVR.self_node[addr].prototype == prototype then
			return ALL_PROXYSVR.self_node[addr]
		else
			local proxy = create_proxysvr(addr, node_name, prototype)
			ALL_PROXYSVR.self_node[addr] = proxy
			return proxy
		end
	else
		-- 跨服节点
		assert(node_name)
		local proxy = ALL_PROXYSVR.othernode[addr] and ALL_PROXYSVR.othernode[addr][node_name]
		if proxy and proxy.prototype == prototype then
			return proxy
		end
		proxy = create_proxysvr(addr, node_name, prototype)
		ALL_PROXYSVR.othernode[addr] = ALL_PROXYSVR.othernode[addr] or {}
		ALL_PROXYSVR.othernode[addr][node_name] = ALL_PROXYSVR.othernode[addr][node_name] or {}
		ALL_PROXYSVR.othernode[addr][node_name] = proxy
		return proxy
	end
end

-- 获取当前节点的服务代理
-- function GetProxyByServiceName(serviceName, prototype, serverId)
-- 	local namedData = UNIQ_SERVICE_CFG[serviceName]
-- 	if namedData then
-- 		assert(namedData.named)
-- 		return GetProxy(namedData.named, SELF_IPPORT, prototype)
-- 	end

-- 	namedData = GAME_SERVICE_CFG[serviceName]
-- 	if namedData then
-- 		assert(namedData.named)
-- 		return GetProxy(namedData.named, SELF_IPPORT, prototype)
-- 	end
-- end

function GetProxyByServiceName(serviceName, ...)
	local count = select("#", ...)
	local nodeName, prototype, serverId = SELF_IPPORT, "lua", host_id -- 默认值
	-- local nodeName, prototype, serverId
	if count == 2 then
		-- 2个参数
		prototype, serverId = ...
	elseif count == 3 then
		-- 3个参数
		nodeName, prototype, serverId = ...
	end
	assert(nodeName and prototype and serverId)
	local namedData = UNIQ_SERVICE_CFG[serviceName]
	if namedData then
		assert(namedData.named)
		return GetProxy(namedData.named, SELF_IPPORT, prototype)
	end

	namedData = SERVICE_NAME[nodeName] and SERVICE_NAME[nodeName][serviceName]
	if namedData then
		print("nodeName, prototype, serverId ", nodeName, prototype, serverId)
		assert(namedData.named)
		return GetProxy(namedData.named, nodeName, prototype)
	end
end

function GetIpport(serverId)
	return ALL_SERVERID_MAP[serverId] and
			ALL_SERVERID_MAP[serverId].self_ipport
end

function GetNodeName(serverId)
	return ALL_SERVERID_MAP[serverId] and
			ALL_SERVERID_MAP[serverId].node
end
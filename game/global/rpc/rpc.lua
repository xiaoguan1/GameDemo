local skynet = require "skynet"
local RPCTIMEOUT_CHECKTIME = 200
local os_time = os.time
local sfind = string.find
local sformat = string.format
local table = table
local thas_value = table.has_value
local RPCTIMEOUT_SEC = 2
local MEAT_READONLY = {__newindex = function (t, k, v)
	error("read only")
end}

local PROXYSVR = Import("game/global/rpc/proxysvr.lua")

local node = assert(skynet.getenv("node")) -- 该进程的节点类型
local ALL_SERVERID_MAP = assert(ALL_SERVERID_MAP)
local SELF_NODE = assert(SELF_NODE)
local SELF_IPPORT = assert(SELF_IPPORT)
local NODE_LIST = NODE_LIST
local ADHOC_SERVICE_MAP = assert(ADHOC_SERVICE_MAP)
local BASIC_SERVICE_MAP = assert(BASIC_SERVICE_MAP)

mod_call = {}
-- mod_send = {}




local function initModCall()
	local cache1 = {}
	local cache2 = {}

	local scache1 = {}

	for _, serviceMap in pairs({BASIC_SERVICE_MAP, ADHOC_SERVICE_MAP}) do
		for svr, data in pairs(serviceMap) do
			if not mod_call[svr] then
				mod_call[svr] =  setmetatable({}, {
					__index = function (_, modOraddr)
						if string.find(modOraddr, ":") then
							-- 网络地址
							local ipportAddr = modOraddr
							if not cache1[ipportAddr] then
								cache1[ipportAddr] = setmetatable({}, {
									__index = function (_, modName)
										if not cache2[modName] then
											cache2[modName] = setmetatable({}, {
												__index = function (_, funcName)
													-- PROXYSVR.
													return print
												end,
												__newindex = function (_, k, v)
													error(sformat("not modify. key[%s] value[%s]", k, v))
												end,
											})
										end
										return cache2[modName]
									end,
									__newindex = function (_, k, v)
										error(sformat("not modify. key[%s] value[%s]", k, v))
									end,
								})
							end
							return cache1[ipportAddr]

						else
							-- 本地服务
							local modName = modOraddr
							local ipportAddr = SELF_IPPORT
							if not scache1[modName] then
								scache1[modName] = setmetatable({}, {
									__index = function (_, funcName)
										-- PROXYSVR.
										return print
									end,
									__newindex = function (_, k, v)
										error(sformat("not modify. key[%s] value[%s]", k, v))
									end,
								})
							end
							return scache1[modName]
						end
					end,
					__newindex = function (_, k, v)
						error(sformat("not modify. key[%s] value[%s]", k, v))
					end,
				})
			end
		end
	end
end

-- local function ModSend()
	
-- end


-- function BindAllFunc()
-- 	BindFunc(mod_call, "mod", "call")
-- 	-- BindFunc(obj_call, "obj", "call")
-- 	BindFunc(mod_send, "mod", "send")
-- 	-- BindFunc(obj_send, "obj", "send")
-- 	-- BindFunc(obj_cb_send, "obj_cb", "send")
-- 	-- BindFunc(obj_recall_send, "obj_recall", "send")

-- 	setmetatable(mod_call, MEAT_READONLY)
-- 	-- setmetatable(obj_call, MEAT_READONLY)
-- 	setmetatable(mod_send, MEAT_READONLY)
-- 	-- setmetatable(obj_send, MEAT_READONLY)
-- 	-- setmetatable(obj_cb_send, MEAT_READONLY)
-- 	-- setmetatable(obj_recall_send, MEAT_READONLY)
-- end

-- 全局集群环境
local nodeAddrEnv = {}
local function loadClutserEnv()
	for serverId, data in pairs(ALL_SERVERID_MAP) do
		local node = data.node	-- 进程的节点身份
		for svrName, cfg in pairs(ADHOC_SERVICE_MAP) do
			if data[svrName] and
				(not cfg.host_node or (cfg.host_node and thas_value(cfg.host_node, node)))
			then
				if cfg.unique then
					nodeAddrEnv[cfg.node] = data.self_ipport
				else
					if not nodeAddrEnv[cfg.node] then
						nodeAddrEnv[cfg.node] = {}
					end
					nodeAddrEnv[cfg.node][serverId] = data.self_ipport
				end
			end
		end
		if node == CROSS_NODE or node == USER_NODE then
			if not nodeAddrEnv[node] then
				nodeAddrEnv[node] = {}
			end
			nodeAddrEnv[node][serverId] = data.self_ipport
		end
	end
	print("nodeAddrEnv ", tool.dumptree(nodeAddrEnv))
end

function __init__()
	-- BindAllFunc()
	-- -- 注意：检测是否有rpc网络断开所有才使用fork替代callout，一般不能使用fork
	-- --		用fork需要告诉主程，让主程来判断
	-- local ENV = getfenv(1)
	-- assert(ENV.FCheck)
	-- skynet.fork(function ()
	-- 	while true do
	-- 		skynet.sleep(RPCTIMEOUT_CHECKTIME)
	-- 		TryCall(ENV.FCheck)		-- 一定要有ENV，这样可以达到热更FCheck(这是使用skynet.fork的缺陷)
	-- 	end
	-- end)

	loadClutserEnv()
	initModCall()


end
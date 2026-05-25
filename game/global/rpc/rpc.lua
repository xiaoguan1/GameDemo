local skynet = require "skynet"
local RPCTIMEOUT_CHECKTIME = 200
local os_time = os.time
local sfind = string.find
local RPCTIMEOUT_SEC = 2
local MEAT_READONLY = {__newindex = function (t, k, v)
	error("read only")
end}

local PROXYSVR = Import("game/global/rpc/proxysvr.lua")

local ALL_SERVERID_MAP = assert(ALL_SERVERID_MAP)
local SELF_NODE = assert(SELF_NODE)
local SELF_IPPORT = assert(SELF_IPPORT)
local NODE_LIST = NODE_LIST
local SERVICES_CONFIG = SERVICES_CONFIG

-- mod_call = {}
-- mod_send = {}

-- local function ModCall()
	
-- end

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
local function globalClutserEnv()
	local node2sIds = {}
	for serverId, data in pairs(ALL_SERVERID_MAP) do
		if not node2sIds[data.node] then
			node2sIds[data.node] = {}
		end
		assert(not node2sIds[data.node][serverId])
		node2sIds[data.node][serverId] = data.self_ipport
	end
	for _, nodeName in ipairs(NODE_LIST) do
		if not node2sIds[nodeName] then
			-- nodeName节点，寄生在其他节点中!
			-- 	1.judge节点可寄生在某一个user节点中
			-- 	2.center和adhoc节点可寄生在cross节点中
			
		end
	end
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





end
-- 节点的宏文件
local skynet = require "skynet"
local node = skynet.getenv("node")

-- 每个节点的基础服务
UNIQ_SERVICE_SEQ = {
	{svr = "protosvr", named = ".PROTOSVR"},	-- 协议服务，加载协议和更新协议
	{svr = "gamelog", named = ".GAMELOG"},
	{svr = "stimer", named = ".STIMER"},
	-- {svr = "dbserver", named = ".DBSERVER"},
	{svr = "gcluster", named = ".GCLUSTER"},
	{svr = "manage", named = ".MANAGE"},
}
UNIQ_SERVICE_CFG = {}
for _, v in ipairs(UNIQ_SERVICE_SEQ) do
	UNIQ_SERVICE_CFG[v.svr] = v
end

--[[
概念：
	一个skynet进程可以有多个节点身份（至少一个）！
	假如 user节点 需要启动 jlogin仲裁网关服务，那么该skynet进程 既有 user节点 也有 jlogin节点

	目前，cross可能会启动adhoc节点相关的服务，（某一个）user节点可能会起到 jlogin 服务
]]
USER_NODE = "user"		-- 玩家服节点
CROSS_NODE = "cross"	-- 普通跨服节点
ADHOC_NODE = "adhoc"	-- 临时节点(既也可以看成普通跨服节点)

NODE_LIST = { USER_NODE, CROSS_NODE, ADHOC_NODE, }

-- cross节点必须启动的基础服务
CROSS_MUST_SERVICE_SEQ = {
	{ svr = "display", named = ".DISPLAY", node = CROSS_NODE },
}

-- user节点必须启动的基础服务
USER_MUST_SERVICE_SEQ = {
	{ svr = "display", named = ".DISPLAY", node = USER_NODE },
	-- { svr = "mail", named = ".MAIL", node = USER_NODE },
	-- { svr = "ugate", named = ".UGATE", node = USER_NODE,	},	-- 登录服务(会代理起到agent服务)
	-- { svr = "agent", named = ".AGENT", node = USER_NODE },	-- 玩家服务
}

-- adhoc节点的服务。相对自由，可以在cross服启动。只要是中心服数据库设置了。
-- host_node：宿主节点限制。以example服务为例，允许启动该服务的节点只能是 adhoc 和 cross
ADHOC_SERVICE_SEQ = {
	-- example玩法
	{ svr = "example", named = ".EXAMPLE", node = ADHOC_NODE, host_node = {CROSS_NODE}},

	-- 仲裁登录服务（仲裁玩家登录那个user节点）
	{ svr = "jlogin", named = ".JLOGIN", node = ADHOC_NODE, host_node = {USER_NODE}},

	-- 中心服服务
	-- { svr = "....", named = "....", node = ADHOC_NODE, host_node = {CROSS_NODE} },
}


-- 服务列表信息(node->named)
SERVICES_CONFIG = { }
local function setServiceMap(tbl)
	assert(type(tbl) == "table" and #tbl == table.size(tbl))
	for _, v in ipairs(tbl) do
		local node = v.node or node
		if not SERVICES_CONFIG[node] then
			SERVICES_CONFIG[node] = {}
		end
		if SERVICES_CONFIG[node][v.svr] then
			error(string.format("%s repeat set named[%s]", node, v.svr))
		end
		SERVICES_CONFIG[node][v.svr] = v
	end
end
setServiceMap(CROSS_MUST_SERVICE_SEQ)
setServiceMap(USER_MUST_SERVICE_SEQ)
setServiceMap(ADHOC_SERVICE_SEQ)

-- print("SERVICES_CONFIG:", tool.dumptree(SERVICES_CONFIG))

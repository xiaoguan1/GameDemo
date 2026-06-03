-- 节点的宏文件
local skynet = require "skynet"

-- 每个节点的基础服务
BASIC_SERVICE = {
	{svr = "protosvr", named = ".PROTOSVR"},	-- 协议服务，加载协议和更新协议
	{svr = "gamelog", named = ".GAMELOG"},
	{svr = "stimer", named = ".STIMER"},
	{svr = "dbserver", named = ".DBSERVER"},
	{svr = "gcluster", named = ".GCLUSTER"},
	{svr = "manage", named = ".MANAGE"},
}
BASIC_SERVICE_MAP = {}

--[[
概念：
	一个skynet进程可以有多个节点身份（至少一个）！
	假如 user节点 需要启动 jlogin仲裁网关服务，那么该skynet进程 既有 user节点 也有 jlogin节点

	目前，cross可能会启动adhoc节点相关的服务，（某一个）user节点可能会起到 jlogin 服务
]]
USER_NODE = "user"		-- 玩家服节点
CROSS_NODE = "cross"	-- 跨服节点

NODE_LIST = { USER_NODE, CROSS_NODE, }

-- user节点必须启动的基础服务
USER_BASIC_SERVICE = {
	{ svr = "display", named = ".DISPLAY", node = USER_NODE },
	-- { svr = "mail", named = ".MAIL", node = USER_NODE },
	-- { svr = "ugate", named = ".UGATE", node = USER_NODE,	},	-- 登录服务(会代理起到agent服务)
	-- { svr = "agent", named = ".AGENT", node = USER_NODE },	-- 玩家服务
}
USER_SERVICE_MAP = {}

-- 相对自由，可以在cross服启动，也可以在user节点启动。只要是中心服数据库设置了。
-- host_node：宿主节点限制。以example服务为例，允许启动该服务的节点只能是 cross
-- unique为true，则表示该服务在整个集群中是唯一的
-- node 其目的是为了在rpc.lua可以方便地根据服务名称获取网络地址
ADHOC_SERVICE = {
	-- example玩法
	{ svr = "example", named = ".EXAMPLE", host_node = {CROSS_NODE}},
	{ svr = "display", named = ".DISPLAY", host_node = {CROSS_NODE}},

	-- 仲裁登录服务（仲裁玩家登录那个user节点）
	{ svr = "jlogin", named = ".JLOGIN", unique = true, host_node = {USER_NODE}},

	-- 中心服服务
	-- { svr = "....", named = "....", host_node = {CROSS_NODE} },
}
ADHOC_SERVICE_MAP = {}

CLUSTER_NAME_MATCH = "^(%a+)@(%d+)_(%d+)$"	-- 解析集群节点名称
CLUSTER_NAME_FMT = "%s@%s_%s"				-- 集群名称格式


-- 构建当前进程节点的基础服务映射
for _, v in ipairs(BASIC_SERVICE) do
	assert(not BASIC_SERVICE_MAP[v.svr])
	BASIC_SERVICE_MAP[v.svr] = v
end
for _, v in ipairs(USER_BASIC_SERVICE) do
	assert(not USER_SERVICE_MAP[v.svr])
	USER_SERVICE_MAP[v.svr] = v
end
for _, v in ipairs(ADHOC_SERVICE) do
	assert(not ADHOC_SERVICE_MAP[v.svr])
	ADHOC_SERVICE_MAP[v.svr] = v
end

-- 新增两个宏，分别是cross和user的启动顺序，手动添加
START_USER_SERVICE = {
	"protosvr",
	"gamelog",
	"stimer",
	"dbserver",
	"gcluster",
	"manage",
}

-- 然后根据具体的配置是否是自由的或者必须启动的，尽量简单化不要复杂化。尽量写死为后续的rpc提供便利
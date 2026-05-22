-- 节点的宏文件
local skynet = require "skynet"
local node = skynet.getenv("node")
local is_crossserver = IsCross()


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


CROSS_SERVICE_SEQ = {
	{ svr = "cdisplay", named = ".CDISPLAY", node = "cross"},
}
CROSS_SERVICE_CFG = {}
for _, v in ipairs(CROSS_SERVICE_SEQ) do
	CROSS_SERVICE_CFG[v.svr] = v
end


ADHOC_SERVICE_SEQ = {
	{ svr = "example", named = ".EXAMPLE", node = "adhoc"},
}
ADHOC_SERVICE_CFG = {}
for _, v in ipairs(ADHOC_SERVICE_SEQ) do
	ADHOC_SERVICE_CFG[v.svr] = v
end


USER_SERVICE_SEQ = {
	{ svr = "udisplay", named = ".UDISPLAY", node = "user"},
	{ svr = "mail", named = ".MAIL", node = "user"},
}
USER_SERVICE_CFG = {}
for _, v in ipairs(USER_SERVICE_SEQ) do
	USER_SERVICE_CFG[v.svr] = v
end


NET_SERVICE_SEQ = {
	{ svr = "login", named = ".LOGIN", node = "net"},
}
NET_SERVICE_CFG = {}
for _, v in ipairs(NET_SERVICE_SEQ) do
	NET_SERVICE_CFG[v.svr] = v
end



-- 当前节点的服务列表信息
SERVICE_MAP = {}

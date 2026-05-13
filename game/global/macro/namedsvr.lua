-- 节点的宏文件

local CUSE1 = {mod_send = true, mod_call = true} -- RPC通信类型
-- local CUSE2 = ...

local skynet = require "skynet"
local is_crossserver = skynet.getenv("is_cross") == "true" and true or false


-- 每个节点的基础服务
START_UNIQ_SERVICE = {
	{svr = "protosvr", named = ".PROTOSVR"},	-- 协议服务，加载协议和更新协议
	{svr = "gamelog", named = ".GAMELOG"},
	{svr = "stimer", named = ".STIMER"},
	-- {svr = "dbserver", named = ".DBSERVER"},
	{svr = "gclusterd", named = ".GCLUSTERD"},
	{svr = "manage", named = ".MANAGE"},
}

UNIQ_SERVICE_CFG = {}
for _, v in ipairs(START_UNIQ_SERVICE) do
	UNIQ_SERVICE_CFG[v.svr] = v
end


-- 跨服服务配置
CROSS_NAMED_SERVER_NODE = {
	["crosssvr/cadvarena"] = {
		named = ".CADVARENA",
		node = "cadvarena_node",	-- 注意：根据区服跨服，需要根据需求设置
		servercross = true,
		subsvc = {	-- 跨服内的其他子服务
			-- ["crosssvr/svrbattle"] = {named = ".SVRBATTLE"},
			-- ["crosssvr/display"] = {named = ".DISPLAY"},
			["display"] = {named = ".DISPLAY"},
		},
	},
	-- ["crosssvr/centerchat"] = {
	-- 	named = ".CENTERCHAT",
	-- 	node = "centerchat_node",
	-- },
	-- ["crosssvr/cmultpfcenter"] = {
	-- 	named = ".CMULTPFCENTER",
	-- 	node = "cmultpfcenter_node",
	-- 	isc2c = true,			-- 注意：是否是跨服调用跨服的，如果是则游戏服rpc没有对应的接口
	-- },
	-- ["crosssvr/cmultpfcross_example"] = {
	-- 	named = ".CMPFCROSS_EXAMPLE",
	-- 	node = "cmultpfcross_node",
	-- 	ismultpfcross = true,	-- 注意：这个跨服是游戏服通过中心服获取分配再连接的
	-- 	subsvc = {
	-- 		["crosssvr/cmultpfcross_slvmonitor"] = {named = ".MULTSLVMONITOR"},
	-- 	},
	-- },
	-- ["crosssvr/cmultpfcross_league"] = {
	-- 	named = "CMPFCROSS_LEAGUE",
	-- 	node = "cmultpfcross_node",
	-- 	ismultpfcross = true,
	-- 	subsvc = {
	-- 		["crosssvr/cmultpfcross_slvmonitor"] = {named = ".MULTSLVMONITOR"},
	-- 		["crosssvr/filedisplay"] = {named = ".FILEDISPLAY"},
	-- 		["crosssvr/svrbattle"] = {named = ".SVRBATTLE"},
	-- 		["crosssvr/cmultpfcross_chat"] = {named = ".CROSS_CHAT"},
	-- 	},
	-- },
	-- ...
}

-- 普通跨服启动服务顺序配置
CROSS_SERVICE_STARTSEQ = {
	"display",
}

-- 普通跨服的服务配置
CROSS_SERVICE_CFG = {
	["display"] = {svr = "display", named = ".DISPLAY", cuse = CUSE1, servercross = true,}
}


-- 游戏服启动服务顺序配置（游戏服不支持集群）
GAME_SERVICE_STARTSEQ = {
	"display",
}

-- 游戏服启动服务详情
GAME_SERVICE_CFG = {
	["display"] = {svr = "display", named = ".DISPLAY", cuse = CUSE1},
}

-- 检查游戏服的服务配置
for _, service in pairs(GAME_SERVICE_STARTSEQ) do
	if not GAME_SERVICE_CFG[service] then
		error(string.format("GAME_SERVICE_STARTSEQ:%s not find GAME_SERVICE_CFG cfg", service))
	end
end
for service in pairs(GAME_SERVICE_CFG) do
	if not table.has_value(GAME_SERVICE_STARTSEQ, service) then
		error(string.format("GAME_SERVICE_CFG:%s not find GAME_SERVICE_STARTSEQ cfg", service))
	end
end

-- 当前节点的服务列表信息
SERVICE_MAP = {}
if is_crossserver then
	for _, v in pairs(CROSS_SERVICE_CFG) do
		SERVICE_MAP[v.svr] = v
	end
else
	for service, v in pairs(GAME_SERVICE_CFG) do
		SERVICE_MAP[service] = v
	end
end
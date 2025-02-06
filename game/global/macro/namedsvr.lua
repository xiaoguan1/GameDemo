-- 节点的宏文件

START_UNIQ_SERVICE = {
	{svr = "stimer", named = ".STIMER"},
	{svr = "gamelog", named = ".GAMELOG"},
}
UNIQ_SERVICE = {}
for _, v in ipairs(START_UNIQ_SERVICE) do
	UNIQ_SERVICE[v.svr] = v
end

-- 跨服服务
CROSS_NAMED_SERVER_NODE = {
	["crosssvr/cadvarena"] = {
		named = ".CADVARENA",
		node = "cadvarena_node",	-- 注意：根据区服跨服，需要根据需求设置
		servercross = true,
		subsvc = {	-- 跨服内的其他子服务
			["crosssvr/svrbattle"] = {named = ".SVRBATTLE"},
			["crosssvr/display"] = {named = ".DISPLAY"},
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

------------------------------------
--- 挖坑1：先简化节点与节点之间的验证。注释authCheck函数
------------------------------------

local skynet = require "skynet"
local node = skynet.getenv("node")
local string = string
local sformat = string.format

local string = string
local pairs = pairs
local assert = assert
local pcall = pcall

node_session2co = {}
command = {}
connecting = {}   -- 正在进行节点连接的事件

node_channel = {}	-- 本节点主动连接其他节点的数据缓存
accept_fd = {}		-- 外部节点主动连接本节点的数据缓存

gate_fdx = false	-- gate_fdx服务的地址

function SyncGate(isCall, ...)
	assert(gate_fdx)
	if isCall then
		return skynet.call(gate_fdx, "lua", ...)
	else
		skynet.send(gate_fdx, "lua", ...)
	end
end

-- 开启当前节点监听
local function nodeListen(address)
	-- 肯定是当前节点的，所以不用代理了
	local isOk = SyncGate(true, "listen", address)
	if isOk then
		skynet.error(sformat("gcluster listen open %s", address))
	else
		skynet.error("gclusterd listen open fail!")
	end
end

-- 同步信息的超时检测
local function dealOvertime()
	while true do
		skynet.sleep(100) -- 每秒执行
		local n = skynet.now()
		for _session, _data in pairs(node_session2co) do
			if n >= _data[1] then
				pcall(Ghelper.DealResponse, _session, false, skynet.pack("time out"))
			end
		end
	end
end

skynet.start(function ()
	local dpcluster = skynet.getenv("dpcluster")
	DPCLUSTER_NODE = load("return " .. dpcluster)()

	dofile "game/global/log.lua"

	skynet.dispatch("lua", function (session, source, cmd, ...)
		local f = assert(command[cmd])
		f(source, ...)
	end)

	Ghelper = Import("tool/service/basic/gcluster/gcluster_helper.lua")
	setmetatable(node_channel, { __index = Ghelper.OpenChannel })

	gate_fdx = skynet.newservice("gcluster_gate", skynet.self())
	if node ~= "main" then
		nodeListen(DPCLUSTER_NODE.node_ipport)		-- 开启当前节点 gate_fdx
	else
		local t = node_channel["127.0.0.1:32527"]
		print("t ", tool.dumptree(t))
	end
	skynet.timeout(0, dealOvertime)

end)

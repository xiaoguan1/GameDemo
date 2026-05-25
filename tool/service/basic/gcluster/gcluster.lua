
local skynet = require "skynet"
local node = skynet.getenv("node")
local string = string
local sformat = string.format

local string = string
local pairs = pairs
local assert = assert
local pcall = pcall
local table = table
local tconcat = table.concat

local SELF_IPPORT = SELF_IPPORT

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

-- 根据地址获取节点，isConnect：若找不到则进行网络链接
function GetNodeChannel(address, isConnect)
	if isConnect then
		return node_channel[address]
	end
	return rawget(node_channel, address)
end

-- 消息打包
function MsgPack(msg)
	return tconcat({string.pack(">I2", msg:len()), msg})
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
	dofile "game/global/log.lua"

	skynet.dispatch("lua", function (session, source, cmd, ...)
		local f = assert(command[cmd])
		f(source, ...)
	end)

	Ghelper = Import("tool/service/basic/gcluster/gcluster_helper.lua")
	setmetatable(node_channel, { __index = Ghelper.OpenChannel })

	gate_fdx = skynet.newservice("gcluster_gate", skynet.self())

	-- 暂时调试
	if node ~= "user" then
		nodeListen(SELF_IPPORT)		-- 开启当前节点 gate_fdx
	else
		local t = GetNodeChannel("127.0.0.1:32527", true)
		print("t ", tool.dumptree(t))
	end
	skynet.timeout(0, dealOvertime)

end)

local skynet = require "skynet"

local string = string
local pairs = pairs
local assert = assert
local pcall = pcall

node_session2co = {}
command = {}
connecting = {}   -- 正在进行节点连接的事件
node_channel = {}

-- 开启当前节点监听
local function node_listen(addr, port)
    local gate = skynet.newservice("gate")
    if port == nil then
        addr, port = string.match(addr, "([^:]+):(.*)$")
        assert(addr and port)
    end
    skynet.error("dpclusterd listen on:", port)
    skynet.call(gate, "lua", "open", { address = addr, port = port, nodelay = true, })	-- 肯定是当前节点的，所以不用代理了
end

-- 同步信息的超时检测
local function deal_overtime()
	while true do
		skynet.sleep(100) -- 每秒执行
		local n = skynet.now()
		for _session, _data in pairs(node_session2co) do
			if n >= _data[1] then
				pcall(Ghelper.dealResponse, _session, false, skynet.pack("time out"))
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

	Ghelper = Import("game/gclusterd/gclusterd_helper.lua")
	setmetatable(node_channel, { __index = Ghelper.openChannel })

	node_listen(DPCLUSTER_NODE.node_ipport)		-- 开启当前节点 gate
	skynet.timeout(0, deal_overtime)
end)

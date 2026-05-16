local skynet = require "skynet"
local socketdriver = require "skynet.socketdriver"
local socket_write = assert(socketdriver.send)
local ldpcluster = require "dpcluster.core"
local pcall = pcall
local assert = assert
local pairs = pairs
local type = type
local string = string

local gcluster_auths = assert(skynet.getenv("gcluster_auths"))
local authYes = "1"
local authNo = "0"

local MSG_TYPE_SEND = 1 -- 异步发消息类型
local MSG_TYPE_CALL = 2 -- 同步发消息类型
local MSG_TYPE_MAX = 0xff

-- 加载该文件的判断
assert(node_session2co and connecting and command and node_channel)


----- 局部方法 ------------------------------

local function strPack(str)
	return table.concat({string.pack(">I2", str:len()), str})
end

-- 认证码
local authCode = strPack(gcluster_auths)
local authYesCode = strPack(authYes)
local authNoCode = strPack(authNo)

local AUTH_STATIUS_DO 		= 1		-- 主动做认证（把本节点的认证码发送给对端）
local AUTH_STATIUS_WAIT 	= 2		-- 等待（等待对端把认证码发送过来）
local AUTH_STATIUS_YES 		= 3		-- 认证成功
local AUTH_STATIUS_NO 		= 4		-- 认证失败

local function mergePrototype(msgType, protoType)
	local prototypeId = nil
	if type(protoType) == "string" then
		prototypeId = skynet.get_prototype_id(protoType)
	else
		prototypeId = protoType
	end
	assert(msgType <= MSG_TYPE_MAX)
	return (prototypeId << 8) + msgType
end

local function socketCloseEvent(sockFd)
    if not sockFd then return end
    for _session, _data in pairs(node_session2co) do
       if _data[3] == sockFd then
           pcall(DealResponse, _session, false, skynet.pack("socket close"))
	   end
	end
end

local function send(node, request, padding)
	local c = node_channel[node]
    c:request(request, nil, padding, true)	-- 都不用 lwrite
    return c:sockfd()
end


----- 全局方法 ------------------------------

function DealResponse(session, ok, msg, sz)
    local response_data = node_session2co[session]
    assert(response_data)
    node_session2co[session] = nil
    if not ok then
        skynet.error("DealResponse not ok:", session, skynet.unpack(msg, sz))
	end
	response_data[2](ok, msg, sz)
end

function OpenChannel(t, key)           -- key可以为node名字也可以直接是ip:port
	local ct = connecting[key]
	if ct then
		local co = coroutine.running()
		table.insert(ct, co)
		skynet.wait(co)
		return assert(ct.channel)
	end
	ct = {}
	connecting[key] = ct
	local fd = SyncGate(true, "connect", key)
	if fd then
		t[key] = {
			fd = fd,
			connected = os.time(),	-- 连接成功但需要验证
			is_auth = AUTH_STATIUS_DO,
			co = coroutine.running(),
		}

		-- 发送认证码
		socket_write(fd, authCode)
		skynet.wait(t[key].co)

		assert(t[key] and t[key].is_auth == AUTH_STATIUS_YES)
		ct.channel = t[key]
	end
	connecting[key] = nil
	for _, co in ipairs(ct) do
		skynet.wakeup(co)
	end
	assert(fd, key .. " connect fail")
	skynet.error("gclusterd succeed connect", key)
	return t[key]

	-- local c = sc.channel {
	-- 	host = host,
	-- 	port = tonumber(port),
	-- 	-- response = read_response
    --     nodelay = true,
	-- 	close_event = socketCloseEvent,
	-- 	-- auth = authCheck(key),
	-- }
    -- local succ, err = pcall(c.connect, c, true)
    -- if succ then
	-- 	t[key] = c
	-- 	ct.channel = c
	-- end
	-- connecting[key] = nil
    -- for _, co in ipairs(ct) do
	-- 	skynet.wakeup(co)
	-- end
	-- assert(succ, err)
	-- return c
end

-- 异步发消息
-- node：对方节点信息（ip:port）
-- addr：对方节点的某个服务地址 string
function command.send(_, node, addr, prototype, msg, sz)
	if node == DPCLUSTER_NODE.node_ipport then
		error("send dpclsterd msg to self")
	end
    local request, _session, padding = ldpcluster.pack(0, DPCLUSTER_NODE.node_ipport, addr,
			mergePrototype(MSG_TYPE_SEND, prototype), msg, sz)
	send(node, request, padding)
end


-- 同步发消息
-- overtime：超时时间
-- node：对方节点信息（ip:port）
-- addr：对方节点的某个服务地址 string
function command.call(_, overtime, node, addr, prototype, msg, sz)
    if node == DPCLUSTER_NODE.node_ipport then
		error("call dpulsterd msg to self")
	end
	local request, _session, padding = ldpcluster.pack(nil, DPCLUSTER_NODE.node_ipport, addr, _merge_prototype(MSG_TYPE_CALL, prototype), msg, sz)	-- pack接口会释放msg内存
	local sock_fd = send(node, request, padding)
	if not sock_fd then
		local response_func = skynet.response()
		response_func(false, "socket error")
	else
		node_session2co[_session] = {
			overtime + skynet.now(),
			skynet.response(),
			sock_fd,
		}
	end
end

-- gate服务发来的消息处理
function command.socket(source, subcmd, fd, ...)
	if subcmd == "accept" then
		-- 外部节点主动连接本节点
		local address = ...
		local nodeData = rawget(node_channel, fd)
		if nodeData then
			-- 已存在，拒绝accept
			SyncGate(false, "close_connect", fd)
			skynet.error(string.format("gclusterd socket[%s] %s already exist, refuse accept", fd, address))
			return
		end
		local isOk = skynet.call(source, "lua", "accept", fd)
		if not isOk then
			skynet.error(string.format("gclusterd socket accept from %s fail", address))
			return
		end

		rawset(node_channel, address, {
			fd = fd,
			connected = os.time(),	-- 连接成功但需要验证
			is_auth = AUTH_STATIUS_WAIT,
		})
		skynet.error(string.format("gclusterd socket accept from %s succeed", address))
	elseif subcmd == "close" then
		skynet.error(string.format("gclusterd socket close from %s", "msg"))
	elseif subcmd == "data" then
		local address, msg = ...
		local nodeData = rawget(node_channel, address)
		if not nodeData then
			SyncGate(false, "close_connect", fd)
			skynet.error(string.format("not find nodeData, gclusterd socket:%s recv data:%s", fd, msg))
			return
		end

		if nodeData.is_auth == AUTH_STATIUS_YES then
			-- 消息
			return
		end


		if nodeData.is_auth == AUTH_STATIUS_WAIT then
			-- 接收认证码，进行比对

			if msg == gcluster_auths then
				nodeData.is_auth = AUTH_STATIUS_YES
				socket_write(fd, authYesCode)
			else
				socket_write(fd, authNoCode)
				rawset(node_channel, address, nil)
				SyncGate(false, "close_connect", fd)
				skynet.error(string.format("gclusterd socket[%s] %s authCode error!", fd, msg))
			end
		elseif nodeData.is_auth == AUTH_STATIUS_DO then
			-- 认证码的比对结果
			if msg == authYes then
				nodeData.is_auth = AUTH_STATIUS_YES
			else
				nodeData.is_auth = AUTH_STATIUS_NO
				SyncGate(false, "close_connect", fd)
				skynet.error(string.format("gclusterd socket[%s] %s authCode error!", fd, msg))
			end
			skynet.wakeup(nodeData.co)
			nodeData.co = nil
		end
	end
end

function command.close()
	-- 主动关闭本节点的监听
end

function command.kick()
	-- 主动关闭与本节点监听连接的socket
end
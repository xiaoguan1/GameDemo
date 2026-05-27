local skynet = require "skynet"
local socketdriver = require "skynet.socketdriver"
local socket_write = assert(socketdriver.send)
local ldpcluster = require "dpcluster.core"
local pcall = pcall
local assert = assert
local pairs = pairs
local type = type
local string = string

local MSG_TYPE_SEND = 1 -- 异步发消息类型
local MSG_TYPE_CALL = 2 -- 同步发消息类型
local MSG_TYPE_MAX = 0xff

-- 加载该文件模块时的判断，且这些方法和变量原则上不能热更的！！！
local GetNodeChannel = assert(GetNodeChannel)
local SyncGate = assert(SyncGate)
local node_session2co = assert(node_session2co)
local connecting = assert(connecting)
local command = assert(command)
local node_channel = assert(node_channel)
local MsgPack = assert(MsgPack)
local SELF_IPPORT = SELF_IPPORT

-- 认证码

-- fd的类
local FdClass = Import("tool/service/basic/gcluster/gcluster_fd_class.lua")

----- 局部方法 ------------------------------

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
function SocketErr(address, isPassive)
	assert(address)
	local channelObj = GetNodeChannel(address)
	if channelObj then
		rawset(node_channel, address, nil)
		skynet.error(string.format("%s clear node_channel!", address))
	else
		skynet.error(string.format("%s node_channel not data!", address))
	end

	local ct = connecting[address]
	local ctChannelObj
	if ct then
		ctChannelObj = ct.channel or ct.pre_channel
		ct.channel = nil
		ct.pre_channel = nil
		for _, co in ipairs(ct.co) do
			skynet.wakeup(co)
		end
		skynet.error(string.format("%s clear connecting!", address))
	end

	local fd
	if channelObj then
		fd = channelObj.fd
	elseif ctChannelObj and not channelObj then
		fd = ctChannelObj.fd
	end
	if not isPassive then
		SyncGate(false, "close_connect", fd)
	end
	socketCloseEvent(fd)
	skynet.error(string.format("gcluster socket err! close fd[%s] passive[%s]", fd, isPassive))
end
FdClass.socket_err = SocketErr


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
		table.insert(ct.co, co)
		skynet.wait(co)
		return assert(ct.channel)
	end
	ct = {
		co = {},
		channel = nil,-- 已完成认证的fd对象

		-- 未完成认证的fd对象(socket消息处理需要临时使用到该对象数据)
		pre_channel = nil,
	}
	connecting[key] = ct
	local fd = SyncGate(true, "connect", key)
	if fd then
		local fdObj = FdClass.FdClass:init(fd, {auth = true, address = key})
		ct.pre_channel = fdObj
		fdObj:do_auth()
		ct.pre_channel = nil
		if fdObj:is_auth_yes() then
			rawset(t, key, fdObj)
			ct.channel = fdObj
		else
			skynet.error(string.format("%s auth fail!", key))
		end
	end
	connecting[key] = nil
	for _, co in ipairs(ct.co) do
		skynet.wakeup(co)
	end
	assert(rawget(t, key), key .. " connect fail")
	skynet.error("gclusterd succeed connect", key)
	return t[key]
end

-- 异步发消息
-- node：对方节点信息（ip:port）
-- addr：对方节点的某个服务地址 string
function command.send(_, node, addr, prototype, msg, sz)
	if node == SELF_IPPORT then
		error("send dpclsterd msg to self")
	end
    local request, _session, padding = ldpcluster.pack(0, SELF_IPPORT, addr,
			mergePrototype(MSG_TYPE_SEND, prototype), msg, sz)
	send(node, request, padding)
end


-- 同步发消息
-- overtime：超时时间
-- node：对方节点信息（ip:port）
-- addr：对方节点的某个服务地址 string
function command.call(_, overtime, node, addr, prototype, msg, sz)
    if node == SELF_IPPORT then
		error("call dpulsterd msg to self")
	end
	local request, _session, padding = ldpcluster.pack(nil, SELF_IPPORT, addr, _merge_prototype(MSG_TYPE_CALL, prototype), msg, sz)	-- pack接口会释放msg内存
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
		local channelObj = GetNodeChannel(address)
		if channelObj then
			-- 一般不会！但若已存在则拒绝accept
			SyncGate(false, "close_connect", fd)
			skynet.error(string.format("gclusterd socket[%s] %s already exist, refuse accept", fd, address))
			return
		end
		if connecting[address] then
			-- 一般不会！但若已存在则拒绝accept
			SyncGate(false, "close_connect", fd)
			skynet.error(string.format("gclusterd fd[%s] %s already exist, refuse accept", fd, address))
			return
		end
		local isOk = skynet.call(source, "lua", "accept", fd)
		if not isOk then
			skynet.error(string.format("gclusterd socket accept from %s fail", address))
			return
		end

		-- 仅仅只是完成了网络上的连接，未进行认证处理。先放在connecting，不设置node_channel(若设置，则有可能未认证而被使用)
		connecting[address] = {
			co = {},
			pre_channel = FdClass.FdClass:init(fd, {address = address}),
		}
		skynet.error(string.format("gclusterd socket accept from %s succeed", address))
	elseif subcmd == "close" then
		-- 外部节点主动关闭本节点链接
		local address = ...
		SocketErr(address, true)
		skynet.error(string.format("gclusterd socket close from %s", address))
	elseif subcmd == "data" then
		local address, msg = ...
		local channelObj = GetNodeChannel(address)
		if not channelObj then
			channelObj = connecting[address] and connecting[address].pre_channel
			if not channelObj then
				SyncGate(false, "close_connect", fd)
				skynet.error(string.format("not find nodeData, gclusterd socket:%s recv data:%s", fd, msg))
				return
			end
			-- 处理验证
			channelObj:deal_auth(msg)
			return
		end

		if not channelObj:is_auth_yes() then
			-- 未认证就处理消息？
			skynet.error("not auth!!!!!", tool.dumptree(channelObj))
			return
		end
		-- 处理消息
	elseif subcmd == "error" then
	else
		skynet.error("gclusterd subcmd no matching!", subcmd, fd, ...)
	end
end

function command.close_listen()
	-- 关闭监听（关闭监听不影响现有的socket链接！！！）
	return SyncGate(true, "close_listen")
end

function command.close()
	-- 主动关闭socket链接(非粗暴的方式关闭，等待现有被挂起的协程全部响应完。)
end

function command.kick()
	-- 主动关闭socket链接(粗暴的方式关闭)
end
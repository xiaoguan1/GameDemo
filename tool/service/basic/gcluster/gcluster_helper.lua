local skynet = require "skynet"
local ldpcluster = require "dpcluster.core"
local pcall = pcall
local assert = assert
local pairs = pairs
local type = type
local string = string
local sformat = string.format

local MSG_TYPE_SEND = 1 -- 异步发消息类型
local MSG_TYPE_CALL = 2 -- 同步发消息类型
local MSG_TYPE_MAX = 0xff

-- 加载该文件模块时的判断，且这些方法和变量原则上不能热更的！！！
local GetChannel = assert(GetChannel)
local SyncGate = assert(SyncGate)
local node_session2co = assert(node_session2co)
local connecting = assert(connecting)
local command = assert(command)
local node_channel = assert(node_channel)
local GetClusterAddr = assert(GetClusterAddr)

local SELF_CLUSTERNAME = assert(SELF_CLUSTERNAME)

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

local function _send(clustername, request, padding)
	local fdObj = node_channel[clustername]
	fdObj:write(request, padding)
    return fdObj.fd
end

----- 全局方法 ------------------------------
function SocketErr(clutsername, isPassive)
	assert(clutsername)
	local channelObj = GetChannel(clutsername)
	if channelObj then
		rawset(node_channel, clutsername, nil)
		skynet.error(sformat("%s [%s] clear node_channel!", clutsername, channelObj.address))
	else
		skynet.error(sformat("%s node_channel not data!", clutsername))
	end

	local ct = connecting[clutsername]
	local ctChannelObj
	if ct then
		ctChannelObj = ct.channel or ct.pre_channel
		ct.channel = nil
		ct.pre_channel = nil
		for _, co in ipairs(ct.co) do
			skynet.wakeup(co)
		end
		skynet.error(sformat("%s clear connecting, co len[%s]", clutsername, #ct.co))
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
	skynet.error(sformat("gcluster socket finished! close fd[%s] passive[%s]", fd, isPassive))
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

function OpenChannel(_node_channel, clusterName)           -- key集群名称（例：cross@1_55001）
	local address = GetClusterAddr(clusterName)
	if not address then
		error(sformat("%s not find address", clusterName))
	end
	local ct = connecting[clusterName]
	if ct then
		local co = coroutine.running()
		table.insert(ct.co, co)
		skynet.wait(co)
		return assert(ct.channel)
	end
	ct = {
		co = {},
		channel = nil,			-- 已完成认证的fd对象
		address = address,		-- 网络地址(ip:port)
		clusterName = clusterName,

		-- 未完成认证的fd对象(socket消息处理需要临时使用到该对象数据)
		pre_channel = nil,
	}
	connecting[clusterName] = ct
	connecting[address] = ct	-- 映射作用
	local fd = SyncGate(true, "connect", address)
	if fd then
		local fdObj = FdClass.FdClass:init(fd, {
				auth = true,
				address = address,
				cluster_name = clusterName,
			})
		ct.pre_channel = fdObj
		fdObj:do_auth()
		ct.pre_channel = nil
		if fdObj:is_auth_yes() then
			local oldFdObj = rawget(_node_channel, clusterName)
			if oldFdObj then
				-- 强行关闭最新fd，并将已有的fdObj返回给被沉睡的协程
				fdObj.fd = nil
				ct.channel = oldFdObj
				SyncGate(false, "close_connect", fd)
			else
				rawset(_node_channel, clusterName, fdObj)
				ct.channel = fdObj
			end
		else
			skynet.error(sformat("%s auth fail!", clusterName))
		end
	end
	connecting[clusterName] = nil
	connecting[address] = nil
	for _, co in ipairs(ct.co) do
		skynet.wakeup(co)
	end
	assert(rawget(_node_channel, clusterName), clusterName .. " connect fail")
	skynet.error("gclusterd succeed connect", clusterName)
	return rawget(_node_channel, clusterName)
end

-- 异步发消息
-- node：对方节点信息（ip:port）
-- addr：对方节点的某个服务地址 string
function command.send(_, clustername, addr, prototype, msg, sz)
	if clustername == SELF_CLUSTERNAME then
		error("send gclsterd msg to self")
	end
    local request, _session, padding = ldpcluster.pack(0, SELF_CLUSTERNAME, addr,
			mergePrototype(MSG_TYPE_SEND, prototype), msg, sz)
	_send(clustername, request, padding)
end


-- 同步发消息
-- overtime：超时时间
-- node：对方节点信息（ip:port）
-- addr：对方节点的某个服务地址 string
function command.call(_, overtime, clustername, addr, prototype, msg, sz)
    if clustername == SELF_CLUSTERNAME then
		error("call dpulsterd msg to self")
	end
	local request, _session, padding = ldpcluster.pack(nil, SELF_CLUSTERNAME, addr, mergePrototype(MSG_TYPE_CALL, prototype), msg, sz)	-- pack接口会释放msg内存
	local sock_fd = _send(clustername, request, padding)
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
		-- 因为被链接进来的网络地址是无法确认其身份的，只能在进行认证的过程中确认身份。故只有认证的过程中是否是真正的接受或者拒绝
		local address = ...
		local isOk = skynet.call(source, "lua", "accept", fd)
		if not isOk then
			skynet.error(sformat("gcluster socket accept from %s fail", address))
			return
		end

		-- 仅仅只是完成了网络上的连接，未进行认证处理。先放在connecting，不设置node_channel(若设置，则有可能未认证而被使用)
		-- 并且也不知道该网络地址address，是哪一个节点的(即cluster_name)
		connecting[address] = {
			co = {},
			channel = nil,
			address = address,
			clusterName = nil,
			pre_channel = FdClass.FdClass:init(fd, {address = address}),
		}
		skynet.error(sformat("gcluster socket accept from %s succeed", address))
	elseif subcmd == "close" then
		-- 外部节点主动关闭本节点链接
		local address = ...
		local fdObj = LoopFindChannel(address)
		if not fdObj then
			skynet.error(sformat("gcluster socket close fail. because %s not find fdObj!", address))
			return
		end
		SocketErr(fdObj.cluster_name, true)
	elseif subcmd == "data" then
		local address, msg = ...
		local channelObj = GetChannel(address)
		if not channelObj then
			channelObj = connecting[address] and connecting[address].pre_channel
			 if not channelObj then
				SyncGate(false, "close_connect", fd)
				skynet.error(sformat("%s not find nodeData, gcluster socket:%s recv data:%s", address, fd, msg))
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

function __update__()
	LoadNodeIpMap()
end
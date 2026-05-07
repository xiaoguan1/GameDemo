local skynet = require "skynet"
local sc = require "skynet.socketchannel"
local ldpcluster = require "dpcluster.core"
local dpcluster_auths = assert(skynet.getenv("dpcluster_auths"))
local pcall = pcall
local assert = assert
local pairs = pairs
local type = type
local string = string

local MSG_TYPE_SEND = 1 -- 异步发消息类型
local MSG_TYPE_CALL = 2 -- 同步发消息类型
local MSG_TYPE_MAX = 0xff

-- 加载该文件的判断
assert(node_session2co and connecting and command and node_channel)


----- 局部方法 ------------------------------

local function MergePrototype(msgType, protoType)
	local prototypeId = nil
	if type(protoType) == "string" then
		prototypeId = skynet.get_prototype_id(protoType)
	else
		prototypeId = protoType
	end
	assert(msgType <= MSG_TYPE_MAX)
	return (prototypeId << 8) + msgType
end

local function SocketCloseEvent(sockFd)
    if not sockFd then return end
    for _session, _data in pairs(node_session2co) do
       if _data[3] == sockFd then
           pcall(dealResponse, _session, false, skynet.pack("socket close"))
	   end
	end
end

-- 节点与节点连接的密钥
local function AuthCheck(key)
	return function (sock)
		local authcode = string.pack(">I2", string.len(dpcluster_auths)) .. dpcluster_auths
		local retData = sock:request(authcode, function(_sock)
			local retData = _sock:read(1)
			if retData ~= "1" then
				local msg = string.format("error cross auth:%s, ip_port:%s", retData, key)
				error(msg)
			end
			return true, retData
		end)
	end
end

local function Send(node, request, padding)
	local c = node_channel[node]
    c:request(request, nil, padding, true)	-- 都不用 lwrite
    return c:sockfd()
end


----- 全局方法 ------------------------------

function dealResponse(session, ok, msg, sz)
    local response_data = node_session2co[session]
    assert(response_data)
    node_session2co[session] = nil
    if not ok then
        skynet.error("dealResponse not ok:", session, skynet.unpack(msg, sz))
	end
	response_data[2](ok, msg, sz)
end

function openChannel(t, key)           -- key可以为node名字也可以直接是ip:port
	local ct = connecting[key]
	if ct then
		local co = coroutine.running()
		table.insert(ct, co)
		skynet.wait(co)
		return assert(ct.channel)
	end
	ct = {}
	connecting[key] = ct
	local host, port = string.match(key, "([^:]+):(.*)$")
	local c = sc.channel {
		host = host,
		port = tonumber(port),
		-- response = read_response
        nodelay = true,
		close_event = SocketCloseEvent,
		auth = AuthCheck(key),
	}
    local succ, err = pcall(c.connect, c, true)
    if succ then
		t[key] = c
		ct.channel = c
	end
	connecting[key] = nil
    for _, co in ipairs(ct) do
		skynet.wakeup(co)
	end
	assert(succ, err)
	return c
end

-- 异步发消息
-- node：对方节点信息（ip:port）
-- addr：对方节点的某个服务地址 string
function command.send(_, node, addr, prototype, msg, sz)
	if node == DPCLUSTER_NODE.node_ipport then
		error("send dpclsterd msg to self")
	end
    local request, _session, padding = ldpcluster.pack(0,
			DPCLUSTER_NODE.node_ipport, addr,
			MergePrototype(MSG_TYPE_SEND, prototype),
			msg, sz)
	Send(node, request, padding)
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
	local sock_fd = Send(node, request, padding)
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
function command.socket(source, subcmd, fd, msg)
    
end
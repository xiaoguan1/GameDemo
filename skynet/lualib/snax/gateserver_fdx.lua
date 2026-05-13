-----------------------------------
--- add guanguowei
--- 充分利用socket的全双工特性
-----------------------------------

local skynet = require "skynet"
local netpack = require "skynet.netpack"
local socketdriver = require "skynet.socketdriver"
local string = string

local gateserver = {}

local listen_fd
local queue		-- message queue
local maxclient = 1024	-- max client
local client_number = 0
local CMD = setmetatable({}, { __gc = function() netpack.clear(queue) end })

local nodelay = true	-- 默认开启

local FD_LISTEN = 1		-- fd的种类为监听
local FD_SCOKET = 2		-- fd的种类为socket

local FD_STATUS_PREPARED = 1	-- fd为就绪状态（仅仅发起未被得到响应）
local FD_STATUS_RUN = 2			-- fd为正常状态（已两边得到确认）
local FD_STATUS_CLOSE = 3		-- fd为关闭状态

local connection = {}
-- true : connected
-- nil : closed
-- false : close read

-- 网络fd的缓存
local socket_pool = {
	-- [fd] = {
		-- address,		ip 地址
		-- port,		port 端口
		-- co,			若存在则表示本节点主动操作的（若没有则外部节点发起的）
		-- type,		端口类型 or socket类型
		-- status,		就绪状态（还不能用）、正常状态（可用）
		-- close,		关闭进度（nil、true，最后销毁该fd存储）
	-- },
	-- ...,
}

-- 主动连接网络地址映射fd
local address2fd_pool = {
	-- [ip:port] = fd,
	-- ...
}

local function wakeup(s)
	local co = s and s.co
	if co then
		s.co = nil
		skynet.wakeup(co)
	end
end

function gateserver.openclient(fd)
	local s = socket_pool[fd]
	if s and
		not s.co and
		s.type == FD_SCOKET and s.status == FD_STATUS_PREPARED
		then

		socketdriver.start(fd)
		s.status = FD_STATUS_RUN
	else
		skynet.error(string.format("fd[%s] try open client error! co[%s] type[%s] status[%s]",
			fd, s and s.co, s and s.type, s and s.status))
	end
end

function gateserver.start(handler)
	assert(handler.message and
			handler.open and
			handler.listen and
			handler.connect and
			handler.disconnect
		)

	-- 开启监听
	function CMD.listen( source, conf )
		assert(not listen_fd)
		local address = conf.address or "0.0.0.0"
		local port = assert(conf.port)

		maxclient = conf.maxclient or maxclient
		nodelay = (conf.nodelay ~= nil) and conf.nodelay or nodelay
		skynet.error(string.format("Listen on %s:%d", address, port))

		listen_fd = socketdriver.listen(address, port, conf.backlog)
		assert(socket_pool[listen_fd] == nil)
		local co = coroutine.running()
		local s = {
			co = co,
			status = FD_STATUS_PREPARED,	-- 就绪状态(该监听未得到socket线程响应)
			address = address,
			port = port,
			type = FD_LISTEN,
			create_time = os.time(),
		}
		socket_pool[listen_fd] = s
		skynet.wait(co) -- 挂起当前协程，等待socket线程响应

		assert(s.status == FD_STATUS_PREPARED)
		s.status = FD_STATUS_RUN -- 正常状态(该监听已得到socket线程响应)
		conf.address = s.address
		conf.port = s.port
		socketdriver.start(listen_fd)

		return handler.listen(source, conf)
	end

	-- 关闭监听listen_fd
	function CMD.close_listen()
		local s = listen_fd and socket_pool[listen_fd]
		if not s then
			skynet.error("not find listen_fd, close listen fail!")
			return
		end
		assert(s.status == FD_STATUS_RUN and not s.co)
		s.status = FD_STATUS_CLOSE
		s.co = coroutine.running()
		socketdriver.close(listen_fd)

		-- 挂起当前协程，等待socket线程响应
		skynet.wait(s.co)

		socket_pool[listen_fd] = nil
		listen_fd = nil
		skynet.error("success close listen_fd!")
	end

	-- 本节点主动连接对方监听
	function CMD.connect(source, host, port)
		local address
		if port then
			address = string.format("%s:%s", host, port)
		else
			address = host
			host, port = string.match(host, "([^:]+):(.+)$")
			port = tonumber(port)
		end
		if not port then
			skynet.error(string.format("connect fail, because invalid host[%s] port[%s]", host, port))
			return
		elseif address2fd_pool[address] then
			skynet.error(string.format("forbidden repeat connect, because already  host[%s] port[%s]", host, port))
			return
		end

		local fd = socketdriver.connect(addr, port)
		address2fd_pool[address] = fd
		local co = coroutine.running()
		local s = {
			co = co,
			type = FD_SCOKET,
			status = FD_STATUS_PREPARED, -- 就绪状态（未得到socket线程的响应）
			address = address,
			port = port,
			create_time = os.time(),
		}
		socket_pool[fd] = s
		skynet.wait(co)

		assert(s.status == FD_STATUS_PREPARED)
		s.status = FD_STATUS_RUN -- 正常状态(已得到socket线程响应)

		handler.connect(source, {fd = fd, address = host, port = port})
		return fd, host, port
	end

	-- 当前节点主动关闭网络连接socket
	function CMD.close_connect(fd)
		local s = fd and socket_pool[fd]
		if not s then
			skynet.error("not find fd, close connect fail!")
			return
		end
		assert(s.status == FD_STATUS_RUN and not s.co)
		s.status = FD_STATUS_CLOSE
		s.co = coroutine.running()
		socketdriver.close(listen_fd)

		-- 挂起当前协程，等待socket线程响应
		skynet.wait(s.co)

		socket_pool[fd] = nil
		address2fd_pool[s.address .. ":" .. s.port] = nil
		skynet.error("success close connect fd:" .. fd)
	end




	local MSG = {}

	local function dispatch_msg(fd, msg, sz)
		local s = socket_pool[fd]
		if s and s.type == FD_SCOKET and s.status == FD_STATUS_RUN then
			handler.message(fd, msg, sz)
		else
			skynet.error(string.format("Drop message from fd (%d) : %s", fd, netpack.tostring(msg,sz)))
		end
	end

	MSG.data = dispatch_msg

	local function dispatch_queue()
		local fd, msg, sz = netpack.pop(queue)
		if fd then
			-- may dispatch even the handler.message blocked
			-- If the handler.message never block, the queue should be empty, so only fork once and then exit.
			skynet.fork(dispatch_queue)
			dispatch_msg(fd, msg, sz)

			for fd, msg, sz in netpack.pop, queue do
				dispatch_msg(fd, msg, sz)
			end
		end
	end

	MSG.more = dispatch_queue

	-- 外部节点 主动连接 本节点监听
	function MSG.open(fd, msg)
		if socket_pool[fd] then
			skynet.error(string.format("fd[%s] already exit, unknown error!", fd))
			return
		end
		client_number = client_number + 1
		if client_number >= maxclient then
			socketdriver.shutdown(fd)
			return
		end
		if nodelay then
			socketdriver.nodelay(fd)
		end
		if address2fd_pool[msg] then
			-- 警告，两端之间重复建立链接了。要想watchdog服务发起额外的消息，让它自行裁决。
			skynet.error(string.format("repeat connect! address[%s]", msg))
		end

		local address, port = string.match(msg, "([^:]+):(.+)$")
		socket_pool[fd] = {
			type = FD_SCOKET,
			status = FD_STATUS_PREPARED, -- 就绪状态（未得到watchdog服务确定要不要accept，该外部链接）
			address = address,
			port = port,
			create_time = os.time(),
		}
		-- 通知watchdog服务，让watchdog服务决定accept操作。
		handler.open(fd, msg)
	end

	-- 关闭网络链接或者监听
	function MSG.close(fd)
		-- 注意：当收到该关闭类型的信息的时候，其socket线程内部已经关闭了fd并清空对应缓存，即事后通知！
		local s = socket_pool[fd]
		if fd == listen_fd then
			-- 关闭监听
			assert(s, "listen_fd not have socket_pool data!")
			wakeup(s)
		else
			-- 关闭socket
			client_number = client_number - 1
			if not s then
				socketdriver.close(fd) -- 二次关闭，确保清理
				skynet.error(string.format("unknown fd[%s] close", fd))
				return
			end

			if s.co then
				-- 当前节点主动关闭（因为是主动关闭，故无需再通知watchdog服务了）
				wakeup(s)
			else
				-- 对方节点关闭，即当前节点被动关闭。
				-- socketdriver.close(fd)
				socket_pool[fd] = nil
				address2fd_pool[s.address .. ":" .. s.port] = nil

				-- 通知watchdog服务，让它做相应的清除工作。
				handler.disconnect(fd)
			end
		end
	end

	function MSG.error(fd, msg)
		if fd == listen_fd then
			skynet.error("gateserver accept error:",msg)
		else
			socketdriver.shutdown(fd)
			if handler.error then
				handler.error(fd, msg)
			end
		end
	end

	function MSG.warning(fd, size)
		if handler.warning then
			handler.warning(fd, size)
		end
	end

	function MSG.init(id, addr, port)
		local s = socket_pool[id]
		if s and s.co then
			s.address = addr
			s.port = port
			wakeup(s)
		else
			skynet.error(string.format("%s MSG.init not find record!, id[%s] addr[%s] port[%s] s[%s]", SERVICE_NAME, id, addr, port, s))
		end
	end

	skynet.register_protocol {
		name = "socket",
		id = skynet.PTYPE_SOCKET,	-- PTYPE_SOCKET = 6
		unpack = function ( msg, sz )
			return netpack.filter( queue, msg, sz)
		end,
		dispatch = function (_, _, q, type, ...)
			queue = q
			if type then
				MSG[type](...)
			end
		end
	}

	local function init()
		skynet.dispatch("lua", function (_, address, cmd, ...)
			local f = CMD[cmd]
			if f then
				skynet.ret(skynet.pack(f(address, ...)))
			else
				skynet.ret(skynet.pack(handler.command(cmd, address, ...)))
			end
		end)
	end

	if handler.embed then
		init()
	else
		skynet.start(init)
	end
end

return gateserver

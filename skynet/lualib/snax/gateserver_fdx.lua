-----------------------------------
--- add guanguowei
--- 充分利用socket的全双工特性
-----------------------------------

local skynet = require "skynet"
local netpack = require "skynet.netpack"
local socketdriver = require "skynet.socketdriver"
local string = string
local sformat = string.format

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
	if s and not s.co and
		s.type == FD_SCOKET and s.status == FD_STATUS_PREPARED
	then
		s.co = coroutine.running()
		socketdriver.start(fd)
		skynet.wait(s.co)
		s.status = FD_STATUS_RUN
	else
		skynet.error(sformat("fd[%s] try open client error! co[%s] type[%s] status[%s]",
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

		local isOk
		isOk, listen_fd = pcall(socketdriver.listen, address, port, conf.backlog)
		if not isOk then
			skynet.error(sformat("open listen fail, %s:%s [%s]", address, port, listen_fd))
			return
		end

		assert(socket_pool[listen_fd] == nil)
		local co = coroutine.running()
		local s = {
			co = co,
			status = nil,
			address = address,
			port = port,
			type = FD_LISTEN,
			create_time = os.time(),
		}
		socket_pool[listen_fd] = s
		skynet.wait(co)
		assert(s.status == nil)

		-- socket线程响应，成功开启监听，设置就绪状态
		s.status = FD_STATUS_PREPARED
		conf.address = s.address
		conf.port = s.port

		-- 确认当前服务接收监听的链接信息（等待socket线程响应）
		socketdriver.start(listen_fd)
		s.co = coroutine.running()
		skynet.wait(co)
		assert(s.status == FD_STATUS_PREPARED)

		-- socket线程响应，设置正常运行状态
		s.status = FD_STATUS_RUN
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
			address = sformat("%s:%s", host, port)
		else
			address = host
			host, port = string.match(host, "([^:]+):(.+)$")
			port = tonumber(port)
		end
		if not port then
			skynet.error(sformat("connect fail, because invalid host[%s] port[%s]", host, port))
			return
		elseif address2fd_pool[address] then
			skynet.error(sformat("forbidden repeat connect, because already  host[%s] port[%s]", host, port))
			return
		end

		-- 不允许链接相同节点内的监听
		local listen_s = listen_fd and socket_pool[listen_fd]
		if listen_s and
			listen_s.address == host and listen_s.port == port
		then
			skynet.error(sformat("forbidden connection same node listen! %s:%s", host, port))
			return
		end

		local fd = socketdriver.connect(host, port)
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

		-- 重新获取缓存s，因为有可能连接失败而清空缓存。
		s = socket_pool[fd]
		if not s then
			skynet.error(sformat("%s:%s connection fail", host, port))
			return
		end

		assert(s.status == FD_STATUS_PREPARED)
		s.status = FD_STATUS_RUN -- 正常状态(已得到socket线程响应)
		address2fd_pool[s.address .. ":" .. s.port] = address2fd_pool[s.address .. ":" .. s.port] or fd

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
			skynet.error(sformat("Drop message from fd (%d) : %s", fd, netpack.tostring(msg,sz)))
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
			skynet.error(sformat("fd[%s] already exit, unknown error!", fd))
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
			skynet.error(sformat("repeat connect! address[%s]", msg))
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
				skynet.error(sformat("unknown fd[%s] close", fd))
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

	-- socket线程返回的错误通知
	function MSG.error(fd, msg)
		local s = socket_pool[fd]
		if not s then
			socketdriver.shutdown(fd)
			skynet.error("unknown fd, force socket shutdown!")
			return
		end

		if fd == listen_fd then
			-- 一般是accept的错误
			skynet.error("gateserver_fdx listen accept error: ", msg)
		else
			if s.status == FD_STATUS_PREPARED then
				-- 一般是本节点发起网络连接的错误，强行关闭
				socket_pool[fd] = nil
				address2fd_pool[s.address .. ":" .. s.port] = nil
				socketdriver.shutdown(fd)

				skynet.error(sformat("gateserver_fdx shutdown fd[%s] msg[%s]", fd, msg))

				wakeup(s)
				handler.error(fd, msg)
			else
				-- 一般是已完成连接的socket，暂时不清楚是什么错误。先做打印留下记录。
				skynet.error(sformat("gateserver_fdx fd:[%s] error, status:[%s] msg:[%s]", fd, s.status, msg))
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
			if (s.type == FD_LISTEN and not s.status) or
				s.type == FD_SCOKET
			then
				s.address = addr
				s.port = port
			end
			wakeup(s)
		else
			skynet.error(sformat("%s MSG.init not find record!, id[%s] addr[%s] port[%s] s[%s]",
				SERVICE_NAME, id, addr, port, s))
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
			print("type ", type)
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

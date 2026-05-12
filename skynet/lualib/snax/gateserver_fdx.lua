-----------------------------------
--- add guanguowei
--- 充分利用socket的全双工特性
-----------------------------------

local skynet = require "skynet"
local netpack = require "skynet.netpack"
local socketdriver = require "skynet.socketdriver"

local gateserver = {}

local listen_fd
local queue		-- message queue
local maxclient = 1024	-- max client
local client_number = 0
local CMD = setmetatable({}, { __gc = function() netpack.clear(queue) end })

local nodelay = true	-- 默认开启

local connection = {}
-- true : connected
-- nil : closed
-- false : close read

function gateserver.openclient(fd)
	if connection[fd] then
		socketdriver.start(fd)
	end
end

function gateserver.closeclient(fd)
	local c = connection[fd]
	if c ~= nil then
		connection[fd] = nil
		socketdriver.close(fd)
	end
end

function gateserver.start(handler)
	assert(handler.message)
	assert(handler.connect)

	-- 网络fd的缓存
	local socket_pool = {
		-- [id] = {address, port, co, listen or open},
		-- ...,
	}

	-- 主动连接网络地址映射fd
	local address2fd_pool = {
		-- [ip:port] = fd,
		-- ...
	}

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
		socket_pool[listen_fd] = {
			co = co,
			listen = false,	-- false表示就绪状态
			address = address,
			port = port,
		}
		skynet.wait(co)

		assert(socket_pool[listen_fd].listen == false)
		socket_pool[listen_fd].listen = true -- true表示正式状态
		conf.address = socket_pool[listen_fd].address
		conf.port = socket_pool[listen_fd].port
		socketdriver.start(listen_fd)
		if handler.listen then
			return handler.listen(source, conf)
		end
	end

	-- 关闭监听listen_fd
	function CMD.close()
		assert(listen_fd)
		socketdriver.close(listen_fd)
	end

	-- 主动连接对方监听
	function CMD.connect(source, host, port)
		local address
		if port then
			address = string.format("%s:%s", host, port)
		else
			address = host
			host, port = string.match(host, "([^:]+):(.+)$")
			port = tonumber(port)
		end
		assert(not address2fd_pool[address])
		local fd = socketdriver.connect(addr, port)
		address2fd_pool[address] = fd
		local co = coroutine.running()
		socket_pool[listen_fd] = {
			co = co,
			open = false,	-- false表示就绪状态
			address = address,
			port = port,
		}
		skynet.wait(co)

		assert(socket_pool[listen_fd].open == false)
		socket_pool[listen_fd].open = true -- true表示正式状态



	end


	local MSG = {}

	local function dispatch_msg(fd, msg, sz)
		if connection[fd] then
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

	-- 对方主动连接本节点监听
	function MSG.open(fd, msg)
		client_number = client_number + 1
		if client_number >= maxclient then
			socketdriver.shutdown(fd)
			return
		end
		if nodelay then
			socketdriver.nodelay(fd)
		end
		connection[fd] = true
		handler.open(fd, msg)
	end

	function MSG.close(fd)
		if fd ~= listen_fd then
			client_number = client_number - 1
			if connection[fd] then
				connection[fd] = false	-- close read
			end
			if handler.disconnect then
				handler.disconnect(fd)
			end
		else
			listen_fd = nil
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
			skynet.wakeup(s.co)
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

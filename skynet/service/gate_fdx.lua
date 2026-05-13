local skynet = require "skynet"
local gateserver_fdx = require "snax.gateserver_fdx"

local watchdog
local connection = {}	-- fd -> connection : { fd , client, agent , ip, mode }

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
}

local handler = {}

-- 开启监听回调
function handler.listen(source, conf)
	watchdog = conf.watchdog or source
	return conf.address, conf.port
end

function handler.message(fd, msg, sz)
	-- recv a package, forward it
	local c = connection[fd]
	local agent = c.agent
	if agent then
		-- It's safe to redirect msg directly , gateserver_fdx framework will not free msg.
		skynet.redirect(agent, c.client, "client", fd, msg, sz)
	else
		skynet.send(watchdog, "lua", "socket", "data", fd, skynet.tostring(msg, sz))
		-- skynet.tostring will copy msg to a string, so we must free msg here.
		skynet.trash(msg,sz)
	end
end

function handler.open(fd, addr)
	local c = {
		fd = fd,
		ip = addr,
	}
	connection[fd] = c
	skynet.send(watchdog, "lua", "socket", "open", fd, addr)
end

local function unforward(c)
	if c.agent then
		c.agent = nil
		c.client = nil
	end
end

local function close_fd(fd)
	local c = connection[fd]
	if c then
		unforward(c)
		connection[fd] = nil
	end
end

function handler.disconnect(fd)
	close_fd(fd)
	skynet.send(watchdog, "lua", "socket", "close", fd)
end

function handler.error(fd, msg)
	close_fd(fd)
	skynet.send(watchdog, "lua", "socket", "error", fd, msg)
end

function handler.warning(fd, size)
	skynet.send(watchdog, "lua", "socket", "warning", fd, size)
end

local CMD = {}

-- 将fd绑到其他的服务（address 或者 source）
function CMD.forward(source, fd, client, address)
	local c = assert(connection[fd])
	unforward(c)
	c.client = client or 0
	c.agent = address or source
	gateserver_fdx.openclient(fd)
end

-- 本质上, 二次 socket.start 确认正式连接 
function CMD.accept(source, fd)
	local c = assert(connection[fd])
	unforward(c)
	gateserver_fdx.openclient(fd)
end

function handler.command(cmd, source, ...)
	local f = assert(CMD[cmd])
	return f(source, ...)
end

function handler.connect(fd, addr)
	local c = {
		fd = fd,
		ip = addr,
	}
	connection[fd] = c
end


gateserver_fdx.start(handler)

----------------------------------
--- 作用：gcluster的 fd 类
----------------------------------

local skynet = require "skynet"
local node = skynet.getenv("node") -- 节点类型名称(main、cross、center、其他)

local driver = require "skynet.socketdriver"
local socket_write = assert(driver.send)

local table = table
local tinsert = table.insert
local assert = assert
local os = os
local os_time = os.time
local MsgPack = assert(MsgPack)

authYes = false
authNo = false
gcluster_auths = false
authYesCode = false
authNoCode = false

-- 认证状态类型
local AUTH_STATIUS_DO 		= 1		-- 主动做认证（把本节点的认证码发送给对端）
local AUTH_STATIUS_WAIT 	= 2		-- 等待（等待对端把认证码发送过来）
local AUTH_STATIUS_YES 		= 3		-- 认证成功
local AUTH_STATIUS_NO 		= 4		-- 认证失败

local _ERROR_F = _ERROR_F
local _INFO_F = _INFO_F

FdClass = { __ClassType = "<<gcluster_fd_class>>" }

local function sock_err(obj)
	
end

function FdClass:init(fd, extData)
	assert(fd)
	extData = extData or {}

	local o = {
		__ObjectType = "gcluster_fd_object"
	}

	-- 设置验证状态
	o.auth = extData.auth and AUTH_STATIUS_DO or AUTH_STATIUS_WAIT
	extData.auth = nil

	for k, v in pairs(extData) do
		o[k] = v
	end

	o.fd = fd
	o.connected = os_time()
	o.do_auth = nil	-- 完成认证操作的时间戳

	return setmetatable(o, {__index = self})
end

function FdClass:write(request, padding)
	local fd = assert(self.fd)
	if padding then
		-- 分包发送
		if not socket_write(fd, request) then
			sock_err(self)
		end
		for _, v in ipairs(padding) do
			if not socket_write(fd, v) then
				sock_err(self)
			end
		end
	else
		if not socket_write(fd , request) then
			sock_err(self)
		end
	end

	return true
end

function FdClass:is_auth_yes()
	return self.auth == AUTH_STATIUS_YES
end

function FdClass:is_auth_wait()
	return self.auth == AUTH_STATIUS_WAIT
end

function FdClass:is_auth_do()
	return self.auth == AUTH_STATIUS_DO
end

-- 主动做认证操作
function FdClass:do_auth(msg)
	local authStatus = self.auth
	if not self:is_auth_do() then
		return authStatus
	end

	local fd = assert(self.fd)
	local co = coroutine.running()
	if self.authcoroutine then
		tinsert(self.auth_waitcoroutine, co)
		skynet.wait(co)
	else
		self.auth_coroutine = co
		self.auth_waitcoroutine = {}
		socket_write(fd, msg) -- 发送认证码

		local stime = os_time()
		skynet.wait(co)
		self.do_auth = os_time()
		if (self.do_auth - stime) >= 3 then
			skynet.error("fd[%s] do auth opt, maybe network congestion!")
		end

		-- 唤醒因认证操作而被挂起的协程
		for _, _co in ipairs(self.auth_waitcoroutine) do
			skynet.wakeup(_co)
		end
	end

	-- 获取最新的认证状态
	local nauthStatus = self.auth
	if nauthStatus == AUTH_STATIUS_YES then
		_INFO_F("fd[%s] auth succeed", fd)
	elseif nauthStatus == AUTH_STATIUS_NO then
		_ERROR_F("fd[%s] auth fail", fd)
	else
		_ERROR_F("fd[%s] auth status[%s] error!", fd, nauthStatus)
	end
	return nauthStatus
end

function FdClass:deal_auth(msg)
	local fd = assert(self.fd)
	if self.do_auth then
		return self.auth
	end

	if self:is_auth_wait() then
		-- 接收认证码，进行比对
		local responseCode
		if msg == gcluster_auths then
			self.auth = AUTH_STATIUS_YES
			responseCode = authYesCode
		else
			self.auth = AUTH_STATIUS_NO
			responseCode = authNoCode
		end
		socket_write(fd, responseCode)
	elseif self:is_auth_yes() then
		-- 认证码的比对结果
		if msg == authYes then
			self.auth = AUTH_STATIUS_YES
		else
			self.auth = AUTH_STATIUS_NO
		end

		local co = self.auth_coroutine
		self.auth_coroutine = nil
		skynet.wakeup(co)
	else
		skynet.error("fd[%s] auth status[%s] invalid!!!", self.fd, self.auth)
	end
	return self:is_auth_yes()
end
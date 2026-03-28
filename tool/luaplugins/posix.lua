local posix = require "posix"

function posix.mkdir_p(path)
	if not path then
		return
	end
	local loop, index = 1, 1
	while true do
		if loop >= 100 then
			error("loop too must")
		end
		loop = loop + 1
		local sIndex = string.find(path, "/", index)
		if not sIndex then
			break
		end
		index = sIndex + 1
		local p = string.sub(path, 1, sIndex)
		if not p then
			error("path sub error!")
		end
		posix.mkdir(p)
	end
end

-- 获取文件的最近一次修改时间
function posix.fmtime(path)
	return posix.stat(path, "mtime")
end

function _G.Pid()
	local pinfo = posix.getpid()
	return pinfo and pinfo.pid
end

function _G.Pwd()
	local sinfo = posix.getenv()
	return sinfo and sinfo.PWD
end

function _G.HostName()
	local sinfo = posix.getenv()
	return sinfo and sinfo.HOSTNAME
end

function _G.SysUser()
	local sinfo = posix.getenv()
	return sinfo and sinfo.USER
end
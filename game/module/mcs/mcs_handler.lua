local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local httpd = require "http.httpd"
local socket = require "skynet,socket"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local posix = require "posix"
local table = table
local string = string
local assert = assert
local pairs = pairs
local tonumber = tonumber
local traceback = debug.traceback
local SNODE = skynet.getenv("node")
local LOG_FILE = "mcs.log"
local mcs_noipcheck = skynet.getenv("mcs_noipcheck") == "true"
local is_testserver = skynet.getenv("is_testserver") == "true"
local posix = assert(posix)
local accept_ips_xls = sharedata.query("IpAcceptData")
assert(accept_ips_xls)

local function response(id, ...)
	local ok, err = httpd.write_response(sockethelper.writefunc(id),...)
	if not ok then
		-- if err == sockethelper.socket_error , that means socket closed.
		skynet.error(string.format("dealmcs response error: fd = %d, %s", id, err))
	end
end

local function _DumpFileModifyTime(path, mFileTimeData)
	if not posix.stat(path) then
		_ERROR("not path:" ..  path)
		return
	end

	for file in posix.files(path) do
		if file ~= "." and file ~= ".." and file ~= ".svn" and file ~= ".git" then
			local pathFile = path .. "/" .. file
			local fStat = posix.stat(pathFile)
			local fileType = fStat.type

			if fileType == "directory" then		-- 目录
				if file == "other_setting" and string.endswith(pathFile, "setting/other_setting") then
				else
					_DumpFileModifyTime(pathFile, mFileTimeData)
				end
			elseif fileType == "regular" then	-- 文件
				if string.endswith(file, ".lua") then
					mFileTimeData[pathFile] = fStat.mtime
				end
			else
				_ERROR_F("fileType:%s error", fileType)
			end
		end
	end
end

function GetAllModifyFileTime()
	-- local cmd = "find ./ -type f -name '*.lua' | xargs stat -c '[\"%n\"]=%Y,'"
	-- local pstr = io.popen(cmd)
	-- local data = pstr:read("*all")
	-- pstr:close()
	-- return assert(load("return {" .. data .. "}"))()

	local mFileTimeData = {}
	_DumpFileModifyTime(".", mFileTimeData)
	return mFileTimeData
end

function IsAcceptlp(addr)
	if mcs_noipcheck or is_testserver then
		return true
	end
	local ip, port = addr:match "([^:]+):?(%d*)$"
	if ip then
		if accept_ips_xls[ip] then
			return true
		end
		--内网地址也可
		local nList = string.split(ip, ".")
		if #nList == 4 then
			for k, v in pairs(nList) do
				nList[k] = tonumber(v)
			end
			if nList[1] == 10 then			-- 10.0.0.0/8
				return true
			elseif nList[1] == 172 then		-- 172.16.0.0/12
				if nList[2] >= 16 and nList[2] <= 31 then
					return true
				end
			elseif nList[1] == 192 then		-- 192.168.0.0/16
				if nList[2] == 168 then
					return true
				end
			end
		end
	end
end

function DealMcs(id)
	socket.start(id)
	-- limit request body size to 8192 (you can pass nil to unlimit)
	local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
	if code then
		if code ~= 200 then
			response(id, code)
		else
			-- if url == "/manage/dianjingpay.lua" then
			-- url = url .. "?" .. body
			-- end
			local path, query = urllib.parse(url)
			local q
			if query then
				q = urllib.parse_query(query)
			end
			LOG._INFO("deal mcs:", url)
			if path == "/shutdown" then     -- 关闭服务器
				local SHUTDOWN_SVR = PROXYSVR.GetProxyByServiceName("shutdown")
				SHUTDOWN_SVR.send.shutdown()
				response(id, 200)
				LOG.LOG_EVENT(LOG_FILE, "shutdown", query or "", tool.dump(q))
			elseif path == "/shutdown_other" then
				local SHUTDOWN_SVR = PROXYSVR.GetProxyByServiceName("shutdown")
				SHUTDOWN_SVR.send.shutdown_other(q.name)
				response(id, 200)
				LOG.LOG_EVENT(LOG_FILE, "shutdown_other", query or "", tool.dump(q))
			elseif path == "/shutdown_gate" then
				local SHUTDOWN_SVR = PROXYSVR.GetProxyByServiceName("shutdown")
				SHUTDOWN_SVR.call.shutdown_gate(q.gate_name)
				response(id, 200)
				LOG.LOG_EVENT(LOG_FILE, "shutdown_gate", query or "", tool.dump(q))
			elseif path == "/debug_console" then
				local port = tonumber(q["port"])
				local ip = q["ip"] or "0.0.0.0"
				if not port then
					response(id, 500, "not port")
				else
					skynet.newservice("debug_console", ip, port)
					response(id, 200, "debug_console ok!")
				end
				LOG.LOG_EVENT(LOG_FILE, "debug_console", query or "", tool.dump(q))
			else
				local filename = nil
				if string.sub(path, 1, 1) ~= "/" then
					filename = "service/mcs/" .. path
				else
					filename = "service/mcs" .. path
				end

				local stat = posix.stat(filename)
				if stat and stat.type ~= "directory" then
					local script_mod = Import(filename)
					if not script_mod or not script_mod.handle_request then
						response(id, 404, "import error")
					end
					local ok, code, data, header = xpcall(script_mod.handle_request, traceback, q)
					if not ok then
						response(id, 404, "mcs deal error")
						error(string.format("mes error: %s", code))
					end
					if not code then
						response(id, 404, "not return code")
						error(string.format("mcs not return code! filename:%s query:%s", filename, query or ""))
					end
					LOG.LOG_EVENT(LOG_FILE, filename, query or "", tool.dump(q), code, data)
					response(id, code, data, header)
				else
					LOG.LOG_EVENT(LOG_FILE, filename, query or "", tool.dump(q), 404, "not file")
					response(id, 404, "not file")
					_ERROR_F("mcs error! filename:%s, query:%s", filename, query)
				end
			end
		end
	else
		if url == sockethelper.socket_error then
			skynet.error("dealmcs socket closed")
		else
			skynet.error("dealmcs errir:", url)
		end
	end
	socket.close(id)
end

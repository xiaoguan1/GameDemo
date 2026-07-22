local skynet = require "skynet"
local string = string
local sformat = string.format


local function LogToDb(collName, level, doc)
	-- 注意，字符串的链接不能直接table.concat(arg)
	GAMELOG_SVR = GAMELOG_SVR or PROXYSVR.GetProxyByServiceName("gamelog")
	if GAMELOG_SVR then
		GAMELOG_SVR.send.writedblog(collName, level, doc)
	else
		skynet.error(sformat("not find gamelog service, log:%s traceback:%s", logContext, traceback()))
	end
end

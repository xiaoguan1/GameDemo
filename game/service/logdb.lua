local skynet = require "skynet"
local logdb_infile = skynet.getenv("logdb_infile") == "true" and true or false

RESPONSE = {}
ACCEPT = {}

if logdb_infile then
	skynet.start(function ()
		DBINFILE = Import("module/logdb/dbinfile.lua")
		DBINFILE.StartDb()
	end)
else
	skynet.start(function ()
		DBSAVE = Import("module/logdb/dbsave.lua")
		DBSAVE.StartDb()
	end)
end

local skynet = require "skynet"
local mongo = require "skynet.db.mongo"
local assert = assert
local MongoCenterDb = assert(load("return " .. skynet.getenv("mongo_center_db"))())

MongoHle = false
local function _GetDb()
	if MongoHle then
		return MongoHle
	end
	MongoHle = mongo.client({
		host = MongoCenterDb.host,
		port = MongoCenterDb.port,
	})
	return MongoHle
end

function WriteDb(collName, logTbl)
	assert(_GetDb)
end
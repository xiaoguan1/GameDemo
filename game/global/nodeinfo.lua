local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local assert = assert
local table = table
local pairs = pairs
local string = string
local sformat = string.format
local CENTER_DATABASE = assert(load("return " .. skynet.getenv("centerdatadb_info"))())

local host_id = tonumber(skynet.getenv("server_id"))
local cluster_no = tonumber(skynet.getenv("cluster_no"))
local merge_hosts = skynet.getenv("merge_hosts")
if merge_hosts then
	merge_hosts = assert(load("return " .. merge_hosts))()
end

-- 连接数据库（注意：协程会堵塞）
local function _GetDb()
	local function on_connect(db)
		db:query("set charset utf8")
	end

	local host = CENTER_DATABASE.dbhost
	local port = CENTER_DATABASE.dbport
	local database = CENTER_DATABASE.dbname
	local db = mysql.connect({
		host = host,
		port = port,
		database = database,
		user = CENTER_DATABASE.dbuser,
		password = CENTER_DATABASE.dbpasswd,
		max_pack_size = 2^30,	-- 1GB，设置一个很大的数值，但实际没作用，因为有max_pack_size 4MB限制
		on_connect = on_connect,
	})
	-- 询问query的时候如果是断开的还是会继续连接，直到连接上
	if not db then
		return false, string.format("connect mysql(%s:%s) dbname:%s error!", host, port, database)
	end
	return true, db
end

local selectSql_1 = "select * from server_config where cluster_no = %d;"
local selectSql_2 = "select * from server_config where cluster_no = %d and server_id = %d;"

-- 获取单个阶段的数据
local function getOneNodeData()
	
end

local function getAllNodeData(db)
	assert(db)
	local sql = sformat(selectSql_1, cluster_no)
	local dbRes = db:query(sql)
	if dbRes["badresult"] or #dbRes <= 0 then
		return false, sformat("query:%s database error!, res:%s", sql, tool.dump(dbRes))
	end

	-- print("res ", tool.dumptree(dbRes))
	local serverConfig = {}
	local serviceNode = {}
	for _, data in ipairs(dbRes) do
		local serverId = data.server_id
		if not serverId or serverId <= 0 or serverConfig[serverId] then
			return false, sformat("cluster_no[%s] repeated server_id[%s]", cluster_no, serverId)
		end
		local nodeName = data.node_name
		local startService = {}
		local t = {
			node = nodeName,
			self_ipport = data.ipport,
			jlogin_ipport = data.jlogin_ipport ~= "" and data.jlogin_ipport or nil,
			start_service = startService,
		}
		serverConfig[serverId] = t

		for _, cfg in pairs(ADHOC_SERVICE) do
			if table.has_value(cfg.host_node, nodeName) then
				local isStart = data["is_start_" .. cfg.svr] == 1
				if isStart then
					startService[cfg.svr] = data.ipport	-- 感觉设置1或者true没有任何实际用途，故设置网络地址
				end
				local identity = string.format("%s@%s_%s", nodeName, cluster_no, serverId)
				if cfg.unique then
					if serviceNode[cfg.svr] then
						return false, sformat("cluster_no[%s] server_id[%s] repeated [%s]", cluster_no, serverId, cfg.svr)
					end
					serviceNode[cfg.svr] = identity
				else
					if not serviceNode[cfg.svr] then
						serviceNode[cfg.svr] = {}
					end
					if serviceNode[cfg.svr][serverId] then
						return false, sformat("cluster_no[%s] server_id[%s] repeated [%s]", cluster_no, serverId, cfg.svr)
					end
					serviceNode[cfg.svr][serverId] = identity
				end
			end
		end
	end
	-- print("serverConfig ", tool.dumptree(serverConfig))
	-- print("svr2node ", tool.dumptree(serviceNode))

	return serverConfig, serviceNode
end

-- 注意：里面有协程的，会阻塞当前协程，需要处理重入问题
function GetAllNodeData()
	local ok, db = _GetDb()
	if not ok then
		return false, db
	end
	return getAllNodeData(db)
end


function GetOneNodeData(serverId)
	local ok, db = _GetDb()
	if not ok then
		return false, db
	end
	return getOneNodeData(db)
end
local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local assert = assert
local table = table
local pairs = pairs
local string = string
local sformat = string.format

local nodename = skynet.getenv("node_name")
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

local function getAllNodeData(db)
	assert(db)
	local sql = sformat(selectSql_1, cluster_no)
	local dbRes = db:query(sql)
	if dbRes["badresult"] or #dbRes <= 0 then
		return false, sformat("query:%s database error!, res:%s", sql, tool.dump(dbRes))
	end

	local hostConfig, oSvrConfigMap = nil, {}
	for _, res in ipairs(dbRes) do
		if res.server_id == host_id then
			hostConfig = res
		else
			oSvrConfigMap[res.server_id] = res
		end
	end

	if not hostConfig then
		return false, "not find self server config"
	end
	if hostConfig.node_name ~= nodename then
		return false, sformat("centerdatabase server_config node_name error! %s ~= %s", hostConfig.node_name, nodename)
	end

	local SERVER_CONFIG = {}	-- 全部区服的配置，包括自己

	local startService = {}
	local selfIpPort = hostConfig.ipport
	local hostEnv = {
		server_id = host_id,
		nodename = nodename,
		ipport = selfIpPort,
		jlogin_ipport = hostConfig.jlogin_ipport ~= "" and hostConfig.jlogin_ipport or nil,
		start_service = startService
	}
	for key, val in pairs(hostConfig) do
		local isOk, sIdx, eIdx = string.beginswith(key, "is_start_")
		if isOk then
			local svriceName = string.sub(key, eIdx + 1)
			if svriceName and ADHOC_SERVICE_MAP[nodename][svriceName] then
				if val == 1 then
					startService[svriceName] = selfIpPort
				elseif val ~= 0 and oSvrConfigMap[val] then
					startService[svriceName] = oSvrConfigMap[val].ipport
				end
			end
		end
	end
	-- print("self_config ", tool.dumptree(self_config))
	SERVER_CONFIG[host_id] = hostEnv


	for serverId, config in pairs(oSvrConfigMap) do
		local svrEnv = {}
		-- local svrNodeName = config.
		for key, val in pairs(config) do
			local isOk, sIdx, eIdx = string.beginswith(key, "is_start_")
			if isOk then
				local svriceName = string.sub(key, eIdx + 1)
				if svriceName and ADHOC_SERVICE_MAP[nodename][svriceName] then
				end
			end
		end
	end
	




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
				local identity = string.format(CLUSTER_NAME_FMT, nodeName, cluster_no, serverId)
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
	local serverConfig, serviceNode = getAllNodeData(db)
	db:disconnect()
	return serverConfig, serviceNode
end

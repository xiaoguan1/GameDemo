local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local assert = assert
local table = table
local pairs = pairs
local is_crossserver = (skynet.getenv("is_cross") == "true") and true or false
local CENTER_DATABASE = assert(load("return " .. skynet.getenv("centerdatadb_info"))())
local SNODE = assert(skynet.getenv("node"))
local host_id = tonumber(skynet.getenv("server_id"))
local cluster_no = tonumber(skynet.getenv("cluster_no"))
local merge_hosts = skynet.getenv("merge_hosts")
if merge_hosts then
	merge_hosts = assert(load("return " .. merge_hosts))()
end

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

local function _GetGameNodeInfoByDatabase(db)
	if is_crossserver then
		return false, "can`t use GetGameNodeInfoByDatabase is cross"
	end

	local dpcluster = {}
	local gsql = string.format("select * from game_server where server_id = %d;", host_id)
	local gres = db:query(gsql)
	if gres["badresult"] then
		return false, string.format("query:%s database error! res:%s", gsql, tool.dump(gres))
	end
	local dbData = gres[1]
	local node = SNODE .. "_node"
	local self_ipport = dbData[node .. "_ip"] .. ":" .. dbData[node .. "_port"]
	if not self_ipport then
		return false, string.format("database has`t node:%s", node)
	end
	dpcluster.node_ipport = self_ipport
	dpcluster[node] = self_ipport
	for _key, _value in pairs(dbData) do
		if string.endswith(_key, "_serverid") then
			if _value == host_id then
				return false, string.format("cross:%s can not use same server_id:%s", _key, _value)
			end
			-- 获取数据库
			local csql = string.format("select * from cross_server where server_id = %d;", _value)
			local cres = db:query(csql)
			if cres["badresult"] then
				return false, string.format("query:%s database error! res:%s", csql, tool.dump(cres))
			end
			local crossData = cres[1]
			local node_ipport = crossData["node_ip"] .. ":" .. crossData["node_port"]
			-- 判断是否活动开启，如果不是则报错
			local sIdx = string.find(_key, "_serverid") - 1
			local cNode = string.sub(_key, 1, sIdx) .. "_node"
			local startNodeCol = "is_startup_" .. string.sub(_key, 1, sIdx)
			if crossData[startNodeCol] ~= 1 then
				return false, string.format("cross:%s is not startup in database table:cross_server server_id:%s", _key, _value)
			end
			local namedData = nil
			for _serviceName, _namedData in pairs(CROSS_NAMED_SERVER_NODE) do
				if _namedData.node == cNode then
					namedData = _namedData
				end
			end
			-- 判断一下是否是 servercross 类型的服务
			if namedData and namedData.servercross then
				dpcluster[cNode] = {}
				dpcluster[cNode][host_id] = node_ipport
			else
				dpcluster[cNode] = node_ipport
			end
		end
	end

	local check_svrdata = gres[1]
	for _server_id, _ in pairs(merge_hosts or {}) do
		if _server_id ~= host_id then
			local gsql = string.format("select * from game_server where server_id = %d;", _server_id)
			local gres = db:query(gsql)
			if gres["badresult"] then
				return false, string.format("query merge server:%s database error! res:%s", gsql, tool.dump(gres))
			end

			if #gres == 1 then
				local data = gres[1]
				for _key, _value in pairs(check_svrdata) do
					-- 如果是 servercross 类型的跨服则加对应服的地址
					if string.endswith(_key, "_serverid") then
						local sIdx = string.find(_key, "_serverid") - 1
						local cNode = string.sub(_key, 1, sIdx) .. "_node"
						local startNodeCol = "is_startup_" .. string.sub(_key, 1, sIdx)
						-- 获取数据库
						local csql = string.format("select * from cross_server where server_id = %d;", _value)
						local cres = db:query(csql)
						if cres["badresult"] or #cres ~= 1 then
							return false, string.format("query:%s database error! res:%s", csql, tool.dump(cres))
						end
						local crossData = cres[1]
						local node_ipport = crossData["node_ip"] .. ":" .. crossData["node_port"]
						-- 判断是否活动开启，如果不是则报错
						if crossData[startNodeCol] ~= 1 then
							return false, string.format("cross:%s is not startup in database table:cross_server server_id:%s", _key, data[_key])
						end
						local namedData = nil
						for _serviceName, _namedData in pairs(CROSS_NAMED_SERVER_NODE) do
							if _namedData.node == cNode then
								namedData = _namedData
							end
						end
						-- 判断一下是否是 servercross 类型的跨服
						if namedData and namedData.servercross then
							dpcluster[cNode][_server_id] = node_ipport
						end
					end
				end
			end

		end
	end

	return true, dpcluster
end

local function _GetCrossNodeInfoByDatabase(db)
	if not is_crossserver then
		return false, "can`t use _GetCrossNodeInfoByDatabase is game"
	end

	local csql = string.format("select * from cross_server where server_id = %d;", host_id)
	local gres = db:query(csql)
	if gres["badresult"] or #gres ~= 1 then
		return false, string.format("query:%s database error!, res:%s", csql, tool.dump(gres))
	end
	local dpData = gres[1]
	local node_ipport = dpData["node_ip"] .. ":" .. dpData["node_port"]
	local dpcluster = {node_ipport = node_ipport}
	print("dpData ", tool.dumptree(dpData))
	for _key, _value in pairs(dpData) do
		if string.beginswith(_key, "is_startup_") then
			if _value == 1 then
				local sIdx, eIdx = string.find(_key, "is_startup_")
				local cNode = string.sub(_key, eIdx + 1) .. "_node"
				-- 如果没有对应的服务节点，或者服务节点不是自己的才设置，否则应该设置dpData[cNode]的ipport
				local serverKey = string.sub(_key, eIdx + 1) .. "_serverid"
				if not dpData[serverKey] or dpData[serverKey] == host_id then
					dpcluster[cNode] = node_ipport
				end
			end
		elseif string.endswith(_key, "_serverid") then
			if _value ~= host_id then	-- 不是自己节点
				-- 获取数据库
				local csql = string.format("select * from cross_server where server_id = %d;", _value)
				local cres = db:query(csql)
				if cres["badresult"] or #cres ~= 1 then
					return false, string.format("query:%s database error! res:%s", csql, tool.dump(cres))
				end
				local crossData = cres[1]
				local node_ipport = crossData["node_ip"] .. ":" .. crossData["node_port"]
				-- 判断是否活动开启，如果不是则报错
				local sIdx = string.find(_key, "_serverid") - 1
				local cNode = string.sub(_key, 1, sIdx) .. "_node"
				local startNodeCol = "is_startup_" .. string.sub(_key, 1, sIdx)
				if crossData[startNodeCol] ~= 1 then
					return false, string.format("cross:%s is not startup in database table:cross_server server_id:%s", _key, _value)
				end
				dpcluster[cNode] = node_ipport
			end
		end
	end
	if table.size(dpcluster) <= 1 then
		return false, string.format("server_id:%s not cross activity startup", host_id)
	end
	return true, dpcluster
end

-- 注意：里面有协程的，会阻塞当前协程，需要处理重入问题
function GetGameNodeInfoByDatabase()
	local ok, db = _GetDb()
	if not ok then
		return false, db
	end
	local ok, ret = _GetGameNodeInfoByDatabase(db)
	db:disconnect()
	return ok, ret
end

-- 注意：里面有协程的，会阻塞当前协程，需要处理重入问题
function GetCrossNodeInfoByDatabase()
	local ok, db = _GetDb()
	if not ok then
		return false, db
	end
	local ok, ret = _GetCrossNodeInfoByDatabase(db)
	db:disconnect()
	return ok, ret
end



local CrossServer_SQL = "select * from cross_server where cluster_no = %d and server_id = %d;"

function GetCrossNodeData(db, extData)
	assert(db)
	extData = extData or {}
	local clusterNo = extData.cluster_no or cluster_no
	local serverId = extData.server_id or host_id
	local csql = string.format(CrossServer_SQL, clusterNo, serverId)
	local gres = db:query(csql)
	if gres["badresult"] or #gres ~= 1 then
		return false, string.format("query:%s database error!, res:%s", csql, tool.dump(gres))
	end
	local dpData = gres[1]

	local selfCluster = {}		-- 本节点启动服务详情
	local outCluster = {}		-- 外部节点详情
	for _key, _value in pairs(dpData) do
		if string.beginswith(_key, "is_startup_") then
			local sIdx, eIdx = string.find(_key, "is_startup_")
			local service = string.sub(_key, eIdx + 1)
			if _value == 1 then
				selfCluster[service] = dpData.ipport
			elseif _value > 1 then
				if not outCluster[_value] then
					outCluster[_value] = {}
				end
				outCluster[_value][_key] = service
			end
		end
	end

	for serverId, _keys in pairs(outCluster) do
		local csql = string.format(CrossServer_SQL, clusterNo, serverId)
		local gres = db:query(csql)
		if gres["badresult"] or #gres ~= 1 then
			return false, string.format("query:%s database error!, res:%s", csql, tool.dump(gres))
		end
		local outDpData = gres[1]

		for _key, service in pairs(_keys) do
			if outDpData[_key] ~= 1 then
				return false, string.format("query:%s database error!, res:%s", csql, tool.dump(gres))
			end
			selfCluster[service] = outDpData.ipport
		end
	end
	-- print("ipport ", dpData.ipport)
	-- print("selfCluster ", tool.dumptree(selfCluster))
	return true, dpData.ipport, selfCluster
end




function GetNodeData()
	local ok, db = _GetDb()
	if not ok then
		return false, db
	end

	if is_crossserver then
		return GetCrossNodeData(db)
	else

	end
end













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
	local clusterData = {}
	for _, data in ipairs(dbRes) do
		local serverId = data.server_id
		if not serverId or serverId <= 0 or clusterData[serverId] then
			return false, sformat("cluster_no[%s] repeated server_id[%s]", cluster_no, serverId)
		end
		local nodeName = data.node_name
		local t = {
			node = nodeName,
			self_ipport = data.ipport,
		}
		clusterData[serverId] = t

		if nodeName == CROSS_NODE then
			-- 普通跨服节点
			for key, v in pairs(data) do
				local sIdx, eIdx = string.find(key, "is_start_")
				if sIdx and eIdx then
					local service = string.sub(key, eIdx + 1)
					if v == 1 then
						t[service] = data.ipport
					else
						if v <= 0 then
							return false, sformat("cluster_no[%s] server_id[%s] %s %s invalid", cluster_no, serverId, key, v)
						end
						t[service] = v	-- v是区服编号，稍后查找具体的ipport地址
					end
				end
			end
		elseif nodeName == USER_NODE then
			-- 玩家服节点
			local host, port = string.match(data.jlogin_ipport, "([^:]+):(.+)$")
			if host and port then
				t.jlogin = data.ipport
				t.jlogin_ipport = data.jlogin_ipport
			else
				local jlogin_id = tonumber(data.jlogin_ipport)
				if not jlogin_id or jlogin_id <= 0 then
					return false, sformat("cluster_no[%s] server_id[%s] jlogin_ipport[%s] invalid", cluster_no, serverId, data.jlogin_ipport)
				end
				t.jlogin_id = jlogin_id	-- v是区服编号，稍后查找具体的ipport地址
			end
		else
			return false, sformat("cluster_no[%s] server_id[%s] invalid node[%s]", cluster_no, serverId, nodeName)
		end
	end
	-- print("clusterData ", tool.dumptree(clusterData))

	return clusterData
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
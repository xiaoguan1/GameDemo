-- http://域名:msc端口/manage/update_auto.lua?node_ipport=
-- eg:http://127.0.0.1:53001/manage/update_auto.lua?node_ipport=127.0.0.1:2528&is_errsave=1
-- node_ipport为可选，如果没有则为自己的节点
-- is_errsave为可选，更新的时候如果版本不对也存当前版本
local skynet = require "skynet"
local queue = require "skynet_queue"
local PROXYSVR = Import("base/proxysvr.lua")
local SNODE = assert(skynet.getenv("node"))
local codecache = require "skynet.codecache"
local is_crossserver = skynet.getenv("is_crossserver") == "true" and true or false
local RPC = nil
if SNODE ~= "pbattle" then --战斗服节点
	if is_crossserver then
		RPC = Import("global/cross_rpc.lua")
	else
		RPC = Import("global/rpc.lua")
	end
end

local LOGDB_PROXY = nil
local LOGDB = skynet.getenv("logdb") == "true" and true or false
local logdb_infile = skynet.getenv("logdb_infile") == "true" and true or false
if LOGDB and logdb_infile then
    LOGDB_PROXY = PROXYSVR.GetProxyByServiceName("logdb")
end
CS = queue()

local function _handle_request(params)
	local node_ipport = params["node_ipport"] or DPCLUSTER_NODE.node_ipport
	local lsvr = PROXYSVR.GetProxy("launcher", node_ipport)
	local isErrSave = tonumber(params["is_errsave"]) == 1
	local loadXlsSvr = PROXYSVR.GetProxy(NAMED_SERVER_EVERY.loadxls.named, node_ipport)

	autoupdate_versioncheck(isErrSave)							--检测一下热更版本

	local oModifyData = get_file_modifytime()
	local nModifyData = MCS_HANDLER.GetAllModifyFileTime()

	if RPC and RPC.mod_call.updateproto then
		RPC.mod_call.updateproto.UPDATEPROTO.TryUpdate()		--优先更新协议
	end

	local updateErr = nil

	-- 配置服务优先热更macros如果存在的话
    local LOADXLS_UPDATE_FILES = {}
	for _fileName, _mtime in pairs(nModifyData) do
		if not oModifyData[_fileName] or oModifyData[_fileName] < _mtime then
			local uFile = _fileName
			if string.beginswith(uFile, "./") then
				uFile = string.sub(uFile, 3)
			end
			if string.beginswith(uFile, "base/macros/") then
				table.insert(LOADXLS_UPDATE_FILES, {file = uFile, utype = UPDATE_TYPE.MACROS})
			end
		end
	end
	if #LOADXLS_UPDATE_FILES > 0 then
		local err = lsvr.call.WAIT_UPDATE_AUTO_LISTFILE(LOADXLS_UPDATE_FILES, "loadxls")
		if err then
			updateErr = err
		end
	end

	local isUpdateSetting = false
	for _fileName, _mtime in pairs(nModifyData) do
		if not oModifyData[_fileName] or oModifyData[_fileName] < _mtime then
			local uFile = _fileName
			if string.beginswith(uFile, "./") then
				uFile = string.sub(uFile, 3)
			end

			-- 优先更新表格里面的代码文件，因为后面需要先更新表格
			if string.find(uFile, "^service/loadxls/") then
				local err = lsvr.call.WAIT_UPDATE_AUTO_CMD(uFile)
				if err then
					updateErr = err
				end
			end
		end
	end

	for _fileName, _mtime in pairs(nModifyData) do
		if not oModifyData[_fileName] or oModifyData[_fileName] < _mtime then
			local uFile = _fileName
			if string.beginswith(uFile, "./") then
				uFile = string.sub(uFile, 3)
			end

			-- 先更新表格即可
			if string.find(uFile, "^setting/") then
				loadXlsSvr.call.UpdateFile(uFile)
				isUpdateSetting = true
			end
		end
	end

	local UPDATE_FILES = {}
	-- 更新macros
	for _fileName, _mtime in pairs(nModifyData) do
		if not oModifyData[_fileName] or oModifyData[_fileName] < _mtime then
			local uFile = _fileName
			if string.beginswith(uFile, "./") then
				uFile = string.sub(uFile, 3)
			end

			if string.beginswith(uFile, "base/macros/") then
				oModifyData[_fileName] = _mtime
				-- local err = lsvr.call.WAIT_UPDATE_MACROS_CMD(uFile)
				-- if err then
				--	updateErr = err
				-- end
				table.insert(UPDATE_FILES, {file = uFile, utype = UPDATE_TYPE.MACROS})
			end
		end
	end

	-- 更新文件dofile文件
	for _fileName, _mtime in pairs(nModifyData) do
		if not oModifyData[_fileName] or oModifyData[_fileName] < _mtime then
			local uFile = _fileName
			if string.beginswith(uFile, "./") then
				uFile = string.sub(uFile, 3)
			end

			if UPDATE_DOFILE_FILE[uFile] ~= nil then
				oModifyData[_fileName] = _mtime
				-- lsvr.call.UPDATE_DOFILE_CMD(uFile)
				table.insert(UPDATE_FILES, {file = uFile, utype = UPDATE_TYPE.DOFILE})
			end
		end
	end

	-- 更新lang_text.lua
	local langTextFile = nModifyData["./hsetting/lang_text.lua"] and "./hsetting/lang_text.lua"
	if not langTextFile then
		langTextFile = nModifyData["hsetting/lang_text.lua"] and "hsetting/lang_text.lua"
	end
	if langTextFile then
		if not oModifyData[langTextFile] or oModifyData[langTextFile] < nModifyData[langTextFile] then
			oModifyData[langTextFile] = nModifyData[langTextFile]
			local uFile = langTextFile
			if string.beginswith(uFile, "./") then
				uFile = string.sub(uFile, 3)
		 	end
			-- local err = lsvr.call.WAIT_UPDATE_AUTO_CMD(uFile)
			-- if err then
			--	updateErr = err
			-- end
			table.insert(UPDATE_FILES, {file = uFile, utype = UPDATE_TYPE.IMPORT})
		end
	end

	local modifyScmRoleVar = false
	local modifySyncData = false
	local modifyLogData = false
	local modifyOffBattle = false
	for _fileName, _mtime in pairs(nModifyData) do
		if not oModifyData[_fileName] or oModifyData[_fileName] < _mtime then
			oModifyData[langTextFile] = _mtime

			local uFile = _fileName
			if string.beginswith(uFile, "./") then
				uFile = string.sub(uFile, 3)
			end

			if OFFLINE_BATTLE_DOFILE_MAP[uFile] or uFile == "gservice/svrbattle/svrbattle.lua" then
				modifyOffBattle = true
			elseif uFile == "service/agent/char/role/role_class.lua" then
				_WARN("Can't update service/agent/char/role/role_class.lua")
			else
				-- 需要使用call,防止异步重复加载报错，例如某个模块1加载新配匿则会异步等待返回，这时另一个模块2又加载模块1
				-- local err = lsvr.WAIT_UPDATE_AUTO_CMD(uFile)
				-- if err then
				--	updateErr = err
				-- end
				table.insert(UPDATE_FILES, {file = uFile, Utype = UPDATE_TYPE.IMPORT})
				if uFile == "charvar/agent/scm_rolevar.lua" then
					modifyScmRoleVar = true
				end
				if uFile == "setting/sync/sync_data.lua" then
					modifySyncData = true
				end
				if uFile == "setting/log/log_data.lua" then
					modifyLogData = true
				end
			end
		end
	end

	if #UPDATE_FILES > 0 then
		local err = lsvr.call.WAIT_UPDATE_AUTO_LISTFILE(UPDATE_FILES)
		if err then
			updateErr = err
		end
	end

	if modifyOffBattle then
		for _, _file in pairs(OFFLINE_BATTLE_DOFILE) do
			codecache.clearone(_file)
		end
		local uFile = "gservice/svrbattle/svrbattle.lua"
		local err = lsvr.call.WAIT_UPDATE_AUTO_CMD(uFile)
		if err then
			updateErr = err
		end
	end

	-- 放在所有更新后再*更罚数据库相关的
	if modifyScmRoleVar then
		local DBALTER = Import("global/dbalter.lua")
		DBALTER.CreateRoleColumns()
	end
	if modifySyncData then
		local DBALTER = Import("global/dbalter.lua")
		DBALTER.CreateSyncDatalable()
	end
	if modifyLogData then
		--【先flush旧的,然后更配表.最后更新数据库，因为flush有1分钟时间差可以放最后，出错概率小一些】
		if LOGDB and logdb_infile then
			LOGDB_PROXY.send.flushallfile2db()
			loadXlsSvr.call.UpdateFile("^setting/log/log_data.lua", true)	-- 更新配置
			local DBALTER = Import("global/dbaiter.Aua")
			DBALTER.CreateGameLogTable()
		end
	end
	if isUpdateSetting then
		SettingCollect() -- 垃圾回收
	end
	if updateErr then
		return 404, updateErr
	end
	return 200, "hotfix ok"
end

function handle_request(params)
	return CS(_handle_request, params)
end
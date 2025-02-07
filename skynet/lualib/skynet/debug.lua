local table = table
local extern_dbgcmd = {}

local function init(skynet, export)
	local internal_info_func

	function skynet.info_func(func)
		internal_info_func = func
	end

	local dbgcmd

	local function init_dbgcmd()
		dbgcmd = {}

		function dbgcmd.MEM()
			local kb = collectgarbage "count"
			skynet.ret(skynet.pack(kb))
		end

		local gcing = false
		function dbgcmd.GC()
			if gcing then
				return
			end
			gcing = true
			local before = collectgarbage "count"
			local before_time = skynet.now()
			collectgarbage "collect"
			-- skip subsequent GC message
			skynet.yield()
			local after = collectgarbage "count"
			local after_time = skynet.now()
			skynet.error(string.format("GC %.2f Kb -> %.2f Kb, cost %.2f sec", before, after, (after_time - before_time) / 100))
			gcing = false
		end

		function dbgcmd.SHAREDATA_FLUSH()
			if SHAREDATA_NEED_FLUSH then
				local sharedata = require "skynet.sharedata"
				sharedata.flush()
			end
			skynet.ret(skynet.pack(nil))
		end

		function dbgcmd.STAT()
			local stat = {}
			stat.task = skynet.task()
			stat.mqlen = skynet.stat "mqlen"
			stat.cpu = skynet.stat "cpu"
			stat.message = skynet.stat "message"
			skynet.ret(skynet.pack(stat))
		end

		function dbgcmd.KILLTASK(threadname)
			local co = skynet.killthread(threadname)
			if co then
				skynet.error(string.format("Kill %s", co))
				skynet.ret()
			else
				skynet.error(string.format("Kill %s : Not found", threadname))
				skynet.ret(skynet.pack "Not found")
			end
		end

		function dbgcmd.TASK(session)
			if session then
				skynet.ret(skynet.pack(skynet.task(session)))
			else
				local task = {}
				skynet.task(task)
				skynet.ret(skynet.pack(task))
			end
		end

		function dbgcmd.UNIQTASK()
			skynet.ret(skynet.pack(skynet.uniqtask()))
		end

		function dbgcmd.INFO(...)
			if internal_info_func then
				skynet.ret(skynet.pack(internal_info_func(...)))
			else
				skynet.ret(skynet.pack(nil))
			end
		end

		function dbgcmd.PROTO_UPDATE(...)
			if pbc_update then
				pbc_update(...)
			end
			skynet.ret(skynet.pack(nil))
		end

		local old_snapshot = nil
		function dbgcmd.SNAPSHOT(isCover)
			if SERVICE_NAME == "sharedatad" then		-- 共享数据的要遍历太久了
				return skynet.ret(skynet.pack(nil))
			end
			local snapshot = require "snapshot"
			local snapshot_utils = require "snapshot_utils"
			local snapshot_search = require "snapshot_search"
			collectgarbage("collect")	-- 为什么两次gc？
			collectgarbage("collect")
			local new_snapshot = snapshot()
			if not old_snapshot then
				old_snapshot = new_snapshot
				return skynet.ret(skynet.pack({}))
			end
			local diff = {}
			for k, v in pairs(new_snapshot) do
				if not old_snapshot[k] then
					diff[k] = v
				end
			end
			if isCover then					-- 默认不覆盖，保证下次也能看到哪里有问题
				old_snapshot = new_snapshot
			end
			local ret = snapshot_utils.construct_indentation(diff)
			local KEY_MAP = {}
			for k, v in pairs(new_snapshot) do
				local key = tostring(k)
				local clean_key = key:match("userdata: 0x(%w+)")
				KEY_MAP[clean_key] = k
			end
			local cache_search = {}
			for _addr, _data in pairs (ret) do
				local path = snapshot_search.search_addresspath(KEY_MAP, _addr, new_snapshot, cache_search)
				_data.snapshot_path = path
			end
			return skynet.ret(skynet.pack(ret))
		end

		local start_snapshot = nil
		function dbgcmd.SNAPSHOT_COMPSTART()
			if SERVICE_NAME == "sharedatad" then		-- 共享数据的要遍历太久了
				return skynet.ret(skynet.pack({"sharedatad can't start snapshot"}))
			end
			local snapshot = require "snapshot"
			local snapshot_utils = require "snapshot_utils"
			local snapshot_search = require "snapshot_search"
			collectgarbage("collect")	-- 为什么两次gc？
			collectgarbage("collect")
			if not start_snapshot then
				return skynet.ret(skynet.pack({"not start snapshot"}))
			end
			local new_snapshot = snapshot()
			local diff = {}
			for k, v in pairs(new_snapshot) do
				if not start_snapshot[k] then
					diff[k] = v
				end
			end
			local ret = snapshot_utils.construct_indentation(diff)
			local KEY_MAP = {}
			for k, v in pairs(new_snapshot) do
				local key = tostring(k)
				local clean_key = key:match("userdata: 0x(%w+)")
				KEY_MAP[clean_key] = k
			end
			local cache_search = {}
			for _addr, _data in pairs(ret) do
				local path = snapshot_search.search_addresspath(KEY_MAP, _addr, new_snapshot, cache_search)
				_data.snapshot_path = path
			end
			return skynet.ret(skynet.pack(ret))

		end

		local isStartSnapshot = nil
		function dbgcmd.STARTSTOP_SNAPSHOT()
			if SERVICE_NAME == "sharedatad" then		-- 共享数据的要遍历太久了
				return skynet.ret(skynet.pack({}))
			end

			-- 内存快照
			local snapshot = require "snapshot"
			local snapshot_utils = require "snapshot_utils"
			local snapshot_search = require "snapshot_search"
			collectgarbage("collect")	-- 为什么两次gc？
			collectgarbage("collect")
			local new_snapshot = snapshot()
			if not start_snapshot then
				start_snapshot = new_snapshot
				return skynet.ret(skynet.pack({}))
			end
			local diff = {}
			for k, v in pairs(new_snapshot) do
				if not start_snapshot[k] then
					diff[k] = v
				end
			end
			local ret = snapshot_utils.construct_indentation(diff)
			local KEY_MAP = {}
			for k, v in pairs(new_snapshot) do
				local key = tostring(k)
				local clean_key = key:match("userdata: 0x(%w+)")
				KEY_MAP[clean_key] = k
			end
			local cache_search = {}
			for _addr, _data in pairs(ret) do
				local path = snapshot_search.search_addresspath(KEY_MAP, _addr, new_snapshot, cache_search)
				_data.snapshot_path = path
			end
			return skynet.ret(skynet.pack(ret))

























		end

		function dbgcmd.PROFILE_CMD(cmd)
			if Import then
				local PROFILE_CMD = Import("global/profile_cmd.lua")
				if cmd == "on" then
					PROFILE_CMD.Profile_On()
				elseif cmd == "off" then
					PROFILE_CMD. Profile_Off()
				elseif cmd == "info" then
					skynet.retpack(PROFILE_CMD.Profile_Info())
					return
				else
					error("not cmd:" .. cmd)
				end
				skynet.retpack(true)
			else
				skynet.retpack(nil)
			end
		end

		local function _table_hasvalue(tbl, value)
			for k, v in pairs(tbl) do
				if v == value then
					return true
				end
			end
		end

		function dbgcmd.UPDATE_DOFILE_CMD(updatefile)
			if UPDATE_DOFILE_FILE and UPDATE_DOFILE_FILE[updatefile] then
				if DOFILELIST and _table_hasvalue(DOFILELIST, updatefile) then
					skynet.error("auto dofile file:" .. updatefile)
					dofile(updatefile)
				end
			end
			skynet.retpack(nil)
		end

		function dbgcmd.UPDATE_AUTO_CMD(updatefile)
			if Import then
				skynet.retpack(UpdateAuto(updatefile))
			else
				skynet.retpack(nil)
			end
		end

		function dbgcmd.UPDATE_MACROS_CMD(updatefile)
			if Import then
				skynet.retpack(UpdateMacro(updatefile))
			else
				skynet.retpack(nil)
			end
		end

		function dbgcmd.EXIT()
			skynet.exit()
		end

		function dbgcmd.RUN(source, filename, ...)
			local inject = require "skynet.inject"
			local args = table.pack(...)
			local ok, output = inject(skynet, source, filename, args, export.dispatch, skynet.register_protocol)
			collectgarbage "collect"
			skynet.ret(skynet.pack(ok, table.concat(output, "\n")))
		end

		function dbgcmd.TERM(service)
			skynet.term(service)
		end

		function dbgcmd.REMOTEDEBUG(...)
			local remotedebug = require "skynet.remotedebug"
			remotedebug.start(export, ...)
		end

		function dbgcmd.SUPPORT(pname)
			return skynet.ret(skynet.pack(skynet.dispatch(pname) ~= nil))
		end

		function dbgcmd.PING()
			return skynet.ret()
		end

		function dbgcmd.LINK()
			skynet.response()	-- get response , but not return. raise error when exit
		end

		function dbgcmd.TRACELOG(proto, flag)
			if type(proto) ~= "string" then
				flag = proto
				proto = "lua"
			end
			skynet.error(string.format("Turn trace log %s for %s", flag, proto))
			skynet.traceproto(proto, flag)
			skynet.ret()
		end

		return dbgcmd
	end -- function init_dbgcmd

	local function _debug_dispatch(session, address, cmd, ...)
		dbgcmd = dbgcmd or init_dbgcmd() -- lazy init dbgcmd
		local f = dbgcmd[cmd] or extern_dbgcmd[cmd]
		assert(f, cmd)
		f(...)
	end

	skynet.register_protocol {
		name = "debug",
		id = assert(skynet.PTYPE_DEBUG),
		pack = assert(skynet.pack),
		unpack = assert(skynet.unpack),
		dispatch = _debug_dispatch,
	}
end

local function reg_debugcmd(name, fn)
	extern_dbgcmd[name] = fn
end

return {
	init = init,
	reg_debugcmd = reg_debugcmd,
}

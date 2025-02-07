--------------------
-- 宏定义常量文件
-- 2025.1.30
--------------------

ONE_DAY_SEC = 86400	-- 一天秒数
ONE_HOUR_SEC = 3600	-- 一小时秒数
ONE_MIN_SEC = 60	-- 一分钟秒数

UPDATE_TYPE = {
	MACROS = 1,     -- macros类型 
	IMPORT = 2,     -- import类型 
	DOFILE = 3,     -- dofile类型 
}

UPDATE_DOFILE_FILE = {
	["service/agent/init/global.lua"] = SERVICE_NAME == "agent" and true or false,
    ["service/gameserver/init/global.lua"] = SERVICE_NAME == "gameserver" and true or false,
    ["service/activity/init/global.lua"] = string.find(SERVICE_NAME, "^actsvc/([%w_]+)") and true or false,
    ["service/cactivity/init/global.lua"] = string.find(SERVICE_NAME, "^crosssvc/([%w_]+)") and true or false,
}

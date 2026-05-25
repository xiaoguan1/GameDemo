local skynet = require "skynet"
require "skynet.manager"
local traceback = debug.traceback

local self_node = skynet.getenv("gcluster_node")
if self_node then
	SELF_NODE = load("return " .. self_node)()
end

local self_ipport = skynet.getenv("self_ipport")
if self_ipport then
	SELF_IPPORT = self_ipport
end

local all_gcluster_node = skynet.getenv("all_gcluster_node")
if all_gcluster_node then
	ALL_GCLUSTER_NODE = load("return " .. all_gcluster_node)()
end

-- 重置随机种子
math.randomseed()

-- 注册的公共协议
skynet.register_protocol({
	name = "callout",
	id = skynet.PTYPE_CALLOUT,
	unpack = skynet.unpack,
	pack = skynet.pack,
})

-- 容错执行函数
local function _RetFunc(isOk, ...)
	if not isOk then
		skynet.error(...)	-- 缺了日志输出，暂用skynet.error代替
	end
	return isOk, ...
end

function TryCall(func, ...)
	return _RetFunc(xpcall(func, traceback, ...))
end

-- lua原生接口函数的拓展（优先加载）
_G.TOOL_FILES = {
	"tool/luaplugins/table.lua",
	"tool/luaplugins/string.lua",
	"tool/luaplugins/tool.lua",
	"tool/luaplugins/posix.lua",
}
for _, pathFile in pairs(TOOL_FILES) do
	if not TryCall(dofile, pathFile) then
		skynet.abort()
	end
end

-- 宏定义
_G.MACRO_FILES = {
	"game/global/macro/common.lua",
	"game/global/macro/namedsvr.lua",
	"game/global/macro/fenv.lua",
	"game/global/macro/color.lua",
}
for _, pathFile in pairs(MACRO_FILES) do
	if not TryCall(dofile, pathFile) then
		skynet.abort()
	end
end

-- 节点类型判断
function IsUser()
	return skynet.getenv("node") == USER_NODE	-- user节点
end
function IsCross()
	return skynet.getenv("node") == CROSS_NODE	-- 一般跨服节点
end
function IsCenter()
	return skynet.getenv("node") == CENTER_NODE	-- 中心服务节点
end
function IsAdhoc()
	return skynet.getenv("node") == ADHOC_NODE	-- 中心服务节点
end

if not _G.Import then
	local func, err = loadfile("tool/luaplugins/import.lua", "bt", _G)
	if not func then
		skynet.error(err)
		skynet.abort()
	end
	if not TryCall(func) then
		skynet.abort()
	end
end

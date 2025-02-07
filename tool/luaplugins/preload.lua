local skynet = require "skynet"

if not _G.Import then
	local func, err = loadfile("tool/luaplugins/import.lua", "bt", _G)
	if not func then
		error(err)
	end
	func()
end

-- 这些文件的全局变量直接赋在_G(慎用)
local GlobalFiles = {
	"game/global/macro/common.lua",
	"game/global/macro/namedsvr.lua",
	"game/global/macro/fenv.lua",
}
for _, f in pairs(GlobalFiles) do
	local func, err = loadfile(f, "bt", _G)
	if not func then
		error(err)
	end
	func()
end


-- 这些文件的全局变量不会附在_G，若有赋在_G的要求可参考tool.lua的做法
local ToolFiles = {
	"tool/luaplugins/table.lua",
	"tool/luaplugins/string.lua",
	"tool/luaplugins/tool.lua",
}
for _, f in pairs(ToolFiles) do
	Import(f)
end

-- 注册的公共协议
skynet.register_protocol({
	name = "callout",
	id = skynet.PTYPE_CALLOUT,
	unpack = skynet.unpack,
	pack = skynet.pack,
})

local posix = require "posix"
function posix.mkdir_p(path)
	if not path then
		return
	end
	local loop, index = 1, 1
	while true do
		if loop >= 100 then
			error("loop too must")
		end
		loop = loop + 1
		local sIndex = string.find(path, "/", index)
		if not sIndex then
			break
		end
		index = sIndex + 1
		local p = string.sub(path, 1, sIndex)
		if not p then
			error("path sub error!")
		end
		posix.mkdir(p)
	end
end
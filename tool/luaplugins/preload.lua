if not _G.Import then
	local func, err = loadfile("tool/luaplugins/import.lua", "bt", _G)
	if not func then
		error(err)
	end
	func()
end

-- 加载文件有顺序要求
local ToolFile = {
	"tool/luaplugins/table.lua",
	"tool/luaplugins/tool.lua",
}
for _, f in pairs(ToolFile) do
	Import(f)
end



-- 洪水填充算法
-- https://blog.csdn.net/qq_46092061/article/details/117092015
-- https://blog.csdn.net/qq_46092061/article/details/117018612

local table = table
local tool = tool

FloodFill = {}
function FloodFill:New(keys, dirs)
	assert(keys and #keys > 0, "please set keys!")
	assert(dirs and #dirs > 0, "please set dirs!")
	local o = {
		keys = table.deepcopy(keys),
		dirs = table.deepcopy(dirs),
	}
	setmetatable(o, {__index = self})
	return o
end

function FloodFill:UpdateKeys(newKeys)
	assert(newKeys and #newKeys > 0, "please set keys!")
	self.keys = table.deepcopy(newKeys)
end

function FloodFill:UpdateDirs(newDirs)
	assert(newDirs and #newDirs > 0, "please set dirs!")
	self.dirs = table.deepcopy(newDirs)
end

-- 生成填充结果
function FloodFill:OutPut(mapData)
	if not mapData then
		_ERROR_F("arg mapData:%s error!", tool.dumptree(mapData))
		return
	end

	local keys = self.keys
	local dirs = self.dirs

	local function dfs(x, y, ocolor, ncolor)
		
	end

	local x, y = 1, 1
	for i = 1, #mapData do
		for j = 1, #mapData[i] do
			
		end
	end



end


local minheap = dofile "MinHeap.lua"

local DIRS = {
	-- 上，下，左、右
	{0, 1}, {0, -1}, {-1, 0}, {1, 0},

	{1, 1}, {1, -1}, {-1, -1}, {-1, 1},
}

-- 节点状态
local STATE = {
	NEW = 1,
	OPEN = 2,
	CLOSED = 3,
}

-- 移动成本
local MOVECOST = 1

-- 地图(横为x轴、竖为y轴)
-- 1:可行、0:障碍
local map_cfg = {
	{1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
	{1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
	{1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
	{1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
	{1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
	{1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
	{1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
	{1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
	{1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
	{1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
	{1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
	{1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
	{1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
}

local function _GetKey(x, y)
	return x << 8 | y
end
local function _IsWalk(x, y)
	return map_cfg[y][x] == 1
end

local DStar = {}
function DStar:new(start, goal)
	local o = {
		start = table.copy(start),
		goal = table.copy(goal),
		openList = minheap:New("key", {"k"}),
		map_data = {}, -- 地图
		current = table.copy(start),
	}

	-- for y = 1, #mdata do
	-- 	self.map_data[y] = {}
	-- 	for x = 1, #mdata[y] do
	-- 		self.map_data[y][x] = {
	-- 			x = x,
	-- 			y = y,
	-- 			state = STATE.NEW,
	-- 			h = 0,
	-- 			k = math.huge,
	-- 			parent = nil,
	-- 			neighbors = {},
	-- 			cost = {}
	-- 		}
	-- 	end
	-- end

	local goalNode = {
		key = _GetKey(o.goal.x, o.goal.y),
		x = o.goal.x,
		y = o.goal.y,
		state = STATE.OPEN,
		h = 0,
		k = 0,
		-- parent = nil,
		-- neighbors = {},
		cost = {},
	}
	o.openList:Push(goalNode)
	setmetatable(o, {__index = self})
	return o
end

function DStar:ProcessState()
	if self.openList:Size() <= 0 then
		return
	end
	local node = self.openList:Pop()
	node.state = STATE.CLOSED

	if not node.neighbors then
		node.neighbors = {}
		for _, v in pairs(DIRS) do
			local x = node.x + v[1]
			local y = node.y + v[2]
			if map_cfg[y][x] then
				
			end
		end
	end



	-- 传播
	if node.k < node.h then
		-- 当h值大于k值时，表示当前该节点处于h值被修改为较大的状态(raise状态)
		-- 为此查找邻居节点来得到减低自身的h值
		for _, v in pairs(DIRS) do
			-- local nbr = {x = }
			local nbrX = node.x + v[1]
			local nbrY = node.y + v[2]
			local cost
			if _IsWalk(nbrX, nbrY) then
				-- local nbr = {x = nbrX, y = nbrY}
				cost = MOVECOST
			else
				cost = math.huge
			end
			if 

		end



		for _, y in ipairs(x.neighbors) do
			if y.h + x.cost[y] < x.h then
				x.parent = y
				x.h = y.h + x.cost[y]
			end
		end
	end

end





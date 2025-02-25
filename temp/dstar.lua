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
local function _SplitKey(key)
	local x = key >> 8
	local y = key & 255
	return x, y
end
local function _CreateNode(x, y)
	return {
		key = _GetKey(x, y),
		x = y,
		y = y,
		state = STATE.NEW,
		h = 0,
		k = 0,
		-- parent = nil,
	}
end
local function _CalcCost(sx, sy, gx, gy)
	return math.abs(gx - sx) + math.abs(gy - sy)
end

local DStar = {}
function DStar:IsWalk(x, y)
	local node = self.map_data[y] and self.map_data[y][x]
	if not node then
		return
	end
	return node.type == 1
end
function DStar:IsValid(x, y)
	return self.map_data[y][x]
end
function DStar:ValidToWalk(x, y)
	return self:IsValid(x, y) and self:IsWalk(x, y)
end
function DStar:GetNode(x, y)
	return self.map_data[y] and self.map_data[y][x]
end
function DStar:GetNodeByKey(key)
	local x, y = _SplitKey(key)
	return self:GetNode(x, y)
end

function DStar:new(mapCfg, start, goal)
	local o = {
		start = table.copy(start),
		goal = table.copy(goal),
		openList = minheap:New("key", {"k"}),
		openSet = {},
		map_data = {}, -- 地图
		current = table.copy(start),
	}

	for y = 1, #mapCfg do
		self.map_data[y] = {}
		for x = 1, #mapCfg[y] do
			self.map_data[y][x] = {
				x = x,
				y = y,
				state = STATE.NEW,
				h = 0,
				k = math.huge,
				parent = nil,
				neighbors = {},
				cost = {},
				type = mapCfg[y][x],
			}
		end
	end

	local goalNode = _CreateNode(o.goal.x, o.goal.y)
	goalNode.state = STATE.OPEN
	-- 预计算邻接关系和移动成本
	-- self:CalcNeighbors(o.goal.x, o.goal.y)
	o.openSet[goalNode.key] = goalNode
	o.openList:Push(goalNode)
	setmetatable(o, {__index = self})
	return o
end

function DStar:CalcNeighbors(node)
	local result = {}
	for _, v in pairs(DIRS) do
		local x = node.x + v[1]
		local y = node.y + v[2]
		if self:IsValid(x, y) then
			local nbr = self.openSet[_GetKey(x, y)]
			if not nbr then
				local nbr = _CreateNode(x, y)
				self.openSet[nbr.key] = nbr
			end
			table.insert(result, nbr)
		end
	end
	return result
end

function DStar:ProcessState()
	if self.openList:Size() <= 0 then
		return
	end
	local node = self.openList:Pop()
	node.state = STATE.CLOSED

	-- 传播
	if node.k < node.h then
		-- 当h值大于k值时，表示当前该节点处于h值被修改为较大的状态(raise状态)
		-- 为此查找邻居节点来得到减低自身的h值
		local neighbors = self:CalcNeighbors(node)
		for _, nbr in pairs(neighbors) do
			local cost
			if self:IsWalk(nbr.x, nbr.y) then
				cost = _CalcCost(node.x, node.y, nbr.x, nbr.y)
			else
				cost = math.huge
			end
			local h = nbr.h + cost
			if h < node.h then
				node.parent = nbr
				node.h = h
			end
		end
	end

	if node.k == node.h then
		local neighbors = self:CalcNeighbors(node)
		for _, nbr in pairs(neighbors) do
			if nbr.state ~= STATE.CLOSED then
				local cost
				if self:IsWalk(nbr.x, nbr.y) then
					cost = _CalcCost(node.x, node.y, nbr.x, nbr.y)
				else
					cost = math.huge
				end
				if (nbr.h > (node.h + cost)) or nbr.parent == node then
					
				end
			end


			if nbr.state ~= STATE.CLOSED and
				(nbr.h > node.h + nbr.cost[node.key] or nbr.parent == node) then
				
			end
		end
	else

	end

	if k_old == x.h then
        for _, y in ipairs(x.neighbors) do
            if y.state ~= "CLOSED" and 
               (y.h > x.h + y.cost[x] or y.parent == x) then
                y.parent = x
                self:insert(y, x.h + y.cost[x])
            end
        end
    else
        for _, y in ipairs(x.neighbors) do
            if y.state ~= "CLOSED" and 
               (y.parent == x or y.h > x.h + y.cost[x]) then
                self:insert(y, y.h)
            end
        end
    end
    
    return self.openList.size
end





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

local DStar = {}
function DStar:CalcCost(sx, sy, gx, gy)
	if self:IsWalk(sx, sy) and self:IsWalk(gx, gy) then
		return math.abs(gx - sx) + math.abs(gy - sy)
	end
	return math.huge
end
function DStar:IsWalk(x, y)
	local key = _GetKey(x, y)
	local mtype1 = self.obs[key]
	local mtype2 = map_cfg[y] and map_cfg[y][x]
	return not (mtype1 == 1 or mtype2 == 1)
end
function DStar:IsValid(x, y)
	return map_cfg[y] and map_cfg[y][x]
end
function DStar:ValidToWalk(x, y)
	return self:IsValid(x, y) and self:IsWalk(x, y)
end
function DStar:GetNode(x, y)
	if not self:IsValid(x, y) then
		return
	end
	local key = _GetKey(x, y)
	local node = self.openSet[key]
	if not node then
		local node = _CreateNode(x, y)
		self.openSet[node.key] = node
	end
	return node
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
		-- map_data = {}, -- 地图
		current = table.copy(start),
		obs = {},
	}

	local goalNode = _CreateNode(o.goal.x, o.goal.y)
	goalNode.state = STATE.OPEN
	-- 预计算邻接关系和移动成本
	-- self:CalcNeighbors(o.goal.x, o.goal.y)
	o.openSet[goalNode.key] = goalNode
	o.openList:Push(goalNode)
	setmetatable(o, {__index = self})
	return o
end

function DStar:Insert(node, newH)
	if node.state == STATE.NEW then
		node.k = newH
	elseif node.state == STATE.OPEN then
		node.k = math.min(node.k, newH)
	else
		node.k = math.min(node.h, newH)
	end

	node.h = newH
	if node.state == STATE.OPEN then
		self.openList:update(node)
	else
		node.state = STATE.OPEN
		self.openList:Push(node)
	end
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
				cost = self:CalcCost(node.x, node.y, nbr.x, nbr.y)
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

	local neighbors = self:CalcNeighbors(node)
	if node.k == node.h then
		for _, nbr in pairs(neighbors) do
			if nbr.state ~= STATE.CLOSED then
				local cost
				if self:IsWalk(nbr.x, nbr.y) then
					cost = self:CalcCost(node.x, node.y, nbr.x, nbr.y)
				else
					cost = math.huge
				end
				if (nbr.h > (node.h + cost)) or nbr.parent == node then
					nbr.parent = x
					self:Insert(nbr, node.h + cost)
				end
			end
		end
	else
		for _, nbr in pairs(neighbors) do
			local cost
			if self:IsWalk(nbr.x, nbr.y) then
				cost = self:CalcCost(node.x, node.y, nbr.x, nbr.y)
			else
				cost = math.huge
			end
			if nbr.state ~= STATE.CLOSED then
				if nbr.parent == node or nbr.h > (node.h + cost) then
					self:insert(nbr, nbr.h)
				end
			end
		end
	end

    return self.openList.size
end

-- 设置障碍并影响周围 ( 周围节点与该节点的代价为math.huge(即h值) )
function DStar:modifyCost(x, y, newCost)
	local node = self:GetNode(x, y)
	if not node then
		error(string.format("set x:%s y:%s cost error!", x, y))
	end
	local key = _GetKey(x, y)
	self.obs[key] = 1

	local neighbors = self:CalcNeighbors(node)
	for _, v in pairs(neighbors) do
		-- 重新回到openList
		if v.state == STATE.CLOSED then
			self:Insert(v, newCost)
		end
	end
	while self:ProcessState() ~= -1 do

	end
end

-- 输出路径
function DStar:findPath()
end


---- 测试用例
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


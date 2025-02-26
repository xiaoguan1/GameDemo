local table = table
if not table.copy then
	function table.copy(t)
		local result = {}
		for k, v in pairs(t) do
			result[k] = v
		end
		return result
	end
end

local minheap = require "minheap"

local MAPTYPE0 = 0
local MAPTYPE1 = 1

local DIRS = {
	-- 上，下，左、右
	{0, 1}, {0, -1}, {-1, 0}, {1, 0},

	{1, 1}, {1, -1}, {-1, -1}, {-1, 1},
}

-- 节点状态
local STATE = { NEW = 1, OPEN = 2, CLOSED = 3, }

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
		-- state = STATE.NEW,
		-- h = 0,
		-- k = 0,
		-- parent = nil,
	}
end

-- D星算法的类模板
local DStar = {}
function DStar:new(map_data)
	local o = {
		map_data = table.copy(map_data),
		role_data = {},	-- 玩家寻路路径数据
		obs = {},		-- 自定义的障碍

		-- 优先队列(最小堆)
		-- openList = minheap:New("key", {"k"}),
	}
	setmetatable(o, {__index = self})
	return o
end

function DStar:GetRoleData(uid)
	return self.role_data[uid]
end

function DStar:CalcCost(sx, sy, gx, gy)
	if self:IsWalk(sx, sy) and self:IsWalk(gx, gy) then
		return math.abs(gx - sx) + math.abs(gy - sy)
	end
	return math.huge
end

-- 坐标是否有效
function DStar:IsValid(x, y)
	return self.map_data[y] and self.map_data[y][x]
end

-- 设置障碍
function DStar:AddObs(x, y)
	if not self:IsValid(x, y) then
		error(string.format("addobs, x:%s y:%s no valid", x, y))
	end
	local key = _GetKey(x, y)
	self.obs[key] = true
end

-- 去除障碍
function DStar:SubObs(x, y)
	if not self:IsValid(x, y) then
		error(string.format("subobs, x:%s y:%s no valid", x, y))
	end
	local key = _GetKey(x, y)
	self.obs[key] = nil
end

function DStar:IsWalk(x, y)
	if not self:IsValid(x, y) then
		return
	end
	local key = _GetKey(x, y)
	if self.obs[key] then
		return
	end
	local mtype = self.map_data[y] and self.map_data[y][x]
	if mtype ~= MAPTYPE1 then
		return
	end
	return true
end

-- 更新地图节点（并影响role_path）
function DStar:modifyMap(x, y, isObs)
	if isObs then
		self:AddObs(x, y)
	else
		self:SubObs(x, y)
	end
end

function DStar:CalcNeighbors(uid, x, y)
	local result = {}
	local roleData = self:GetRoleData(uid)
	if not roleData then
		return
	end
	for _, v in pairs(DIRS) do
		local nbrx = x + v[1]
		local nbry = y + v[2]
		if self:IsValid(nbrx, nbry) then
			local nbr = roleData.openSet[_GetKey(nbrx, nbry)]
			if not nbr then
				local nbr = _CreateNode(x, y)
				roleData.openSet[nbr.key] = nbr
			end
			table.insert(result, nbr)
		end
	end
	return result
end

function DStar:ProcessState(uid)
	local obj = self:GetRoleData(uid)
	if not obj then
		return
	end
	if obj.openList:Size() <= 0 then
		return
	end
	local node = obj.openList:Pop()
	node.state = STATE.CLOSED

	-- 传播
	if node.k < node.h then
		-- 当h值大于k值时，表示当前该节点处于h值被修改为较大的状态(raise状态)
		-- 为此查找邻居节点来得到减低自身的h值
		local neighbors = self:CalcNeighbors(uid, node.x, node.y) or {}
		for _, nbr in pairs(neighbors) do
			local cost = self:CalcCost(node.x, node.y, nbr.x, nbr.y)
			local h = nbr.h + cost
			if h < node.h then
				node.parent = nbr
				node.h = h
			end
		end
	end

	local neighbors = self:CalcNeighbors(uid, node.x, node.y) or {}
	if node.k == node.h then
		for _, nbr in pairs(neighbors) do
			if nbr.state ~= STATE.CLOSED then
				local cost = self:CalcCost(node.x, node.y, nbr.x, nbr.y)
				if (nbr.h > (node.h + cost)) or nbr.parent == node then
					nbr.parent = x
					self:Insert(nbr, node.h + cost)
				end
			end
		end
	else
		for _, nbr in pairs(neighbors) do
			local cost = self:CalcCost(node.x, node.y, nbr.x, nbr.y)
			if nbr.state ~= STATE.CLOSED then
				if nbr.parent == node or nbr.h > (node.h + cost) then
					self:Insert(nbr, nbr.h)
				end
			end
		end
	end

	return obj.openList:Size()
end

function DStar:Insert(uid, node, newH)
	local obj = self:GetRoleData(uid)
	if not obj then
		return
	end
	if node.state == STATE.NEW then
		node.k = newH
	elseif node.state == STATE.OPEN then
		node.k = math.min(node.k, newH)
	else
		node.k = math.min(node.h, newH)
	end

	node.h = newH
	if node.state == STATE.OPEN then
		obj.openList:update(node)
	else
		node.state = STATE.OPEN
		obj.openList:Push(node)
	end
end

-- 添加寻路数据
function DStar:CreateFindPath(uid, start, goal)
	local r = self:GetRoleData(uid)
	assert(not r, string.format("uid:%s already has data", uid))

	local r = {
		start = start,
		goal = goal,
		uid = uid,

		-- 优先队列(最小堆)
		openList = minheap:New("key", {"k"}),
		openSet = {},
	}
	self.role_data[uid] = r
end
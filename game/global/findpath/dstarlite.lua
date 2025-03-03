-- https://blog.csdn.net/mkr67n/article/details/106031055
-- https://github.com/Bastiantheone/DStarLite/blob/master/DStarLite.cs


local minheap = require "minheap"
local math = math

-- 0：障碍、1：可行走
local POS_STATE0 = 0
local POS_STATE1 = 1

local DIRS = {
	-- 上，下，左、右
	{0, 1}, {0, -1}, {-1, 0}, {1, 0},
	{1, 1}, {1, -1}, {-1, -1}, {-1, 1},
}

-- 节点状态
local POS_STATE = { NEW = 1, OPEN = 2, CLOSED = 3, }

-- 局部函数 ---------------------------------
-- 启发式函数（曼哈顿距离）
local function _Heuristic(a, b)
	return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

local function _GetKey(x, y)
	return x << 8 | y
end
local function _SplitKey(key)
	local x = key >> 8
	local y = key & 255
	return x, y
end


DStarLite = {__ClassType = "DStarLite"}
-- DStarLite的构造函数
function DStarLite:New(map_data)
	local o = {
		map_data = map_data,
		role_data = {},	-- 玩家寻路路径数据
	}
	setmetatable(o, {__index = self})
	return o
end

function DStarLite:IsWalk(x, y)
	local state = self.map_data[y] and self.map_data[y][x]
	return state == POS_STATE1
end

function DStarLite:GetRoleData(uid)
	return uid and self.role_data[uid]
end

function DStarLite:GetNode(uid, x, y)
	local key = _GetKey(x, y)
	local rData = self:GetRoleData(uid)
	local node = rData.openSet[key]
	if not node then
		node = {
			key = _GetKey(x, y),
			x = x,
			y = y,
			g = math.huge,		-- 到目标的实际代价
			rhs = math.huge,	-- 基于邻居的最小代价
			k1 = math.huge,
			k2 = math.huge,
			parent = nil,
			state = POS_STATE.NEW,
		}
		rData.openSet[key] = node
	end
	return node
end

-- function DStarLite:Insert(uid, node)
-- 	local rData = self:GetRoleData(uid)
-- 	local k1, k2 = self:CalcKey(uid, node)
-- 	node.k1, node.k2 = k1, k2
-- 	rData.openList:Push(node)
-- end

function DStarLite:UpdateVertex(uid, node)
	-- 当检测到结点G!=Rhs时会将其加入队列（若已在队列中则进行Key更新）
	-- 否则将其从队列中移除
	local rData = self:GetRoleData(uid)
	if not rData then return end
	local isQueue = rData.openList:HasUnique(node.key)
	if node.rhs ~= node.g then
		node.k1, node.k2 = self:CalcKey(uid, node)
		node.state = POS_STATE.OPEN
		if isQueue then
			rData.openList:Modify(node)
		else
			rData.openList:Push(node)
		end
	else
		if isQueue then
			node.state = POS_STATE.CLOSED
			rData.openList:Remove(node.key)
		end
	end
end

-- 添加玩家的寻路事件
function DStarLite:AddRoleEvent(uid, start, goal)
	local rData = self:GetRoleData(uid)
	if rData then
		_ERROR_F("please not repeat add data, uid: start:%s goal:%s", uid, start, goal)
		return
	end

	rData = {
		uid = uid,
		start = table.copy(start),
		goal = table.copy(goal),
		km = 0,

		-- minheap：优先队列(最小堆)
		-- openList：存放节点状态为OPEN的节点。且其按照节点的k值从小到大进行排序
		openList = minheap:New("key", {"k1", "k2"}, true),
		openSet = {},
	}
	self.role_data[uid] = rData
	local gNode = self:GetNode(uid, goal.x, goal.y)
	gNode.rhs = 0
	self:UpdateVertex(uid, gNode)
	return rData
end

-- 计算节点的优先级键值
function DStarLite:CalcKey(uid, node)
	local rData = self:GetRoleData(uid)
	local k2 = math.min(node.g, node.rhs)
	local k1 = k2 + _Heuristic(rData.start, node) + rData.km
	return k1, k2
end

-- 获取邻居
function DStarLite:GetNbrs(uid, node)
	if not node then return end
	local nbrs = {}
	for _, v in pairs(DIRS) do
		local nbrx = node.x + v[1]
		local nbry = node.y + v[2]
		if self:IsWalk(nbrx, nbry) then
			table.insert(nbrs, self:GetNode(uid, nbrx, nbry))
		end
	end
	return nbrs
end

-- 主计算循环
function DStarLite:ComputePath(uid)
	local rData = self:GetRoleData(uid)
	if not rData then return end

	local startX = rData.start.x
	local startY = rData.start.y
	local max_steps = 99999
	while rData.openList:Size() > 0 do
		if max_steps <= 0 then
			print("ComputeShortestPath error: max steps exceeded.")
			break
		end
		max_steps = max_steps - 1
		local current = rData.openList:Pop()
		current.state = POS_STATE.CLOSED
		if current.x == startX and current.y == startY then
			-- 到达终点
			break
		end

		local k1, k2 = self:CalcKey(uid, current)
		if current.k1 < k1 or (current.k1 == k1 and current.k2 < k2) then
			current.k1 = k1
			current.k2 = k2
			current.state = POS_STATE.OPEN
			rData.openList:Push(current)
		elseif current.g > current.rhs then
			current.g = current.rhs
			local newG = current.g + 1
			local nbrs = self:GetNbrs(uid, current) or {}
			for _, nbrNode in pairs(nbrs) do
				local rhs = math.min(nbrNode.rhs, newG)
				if nbrNode.state == POS_STATE.NEW or
					(nbrNode.parent == current and nbrNode.rhs ~= rhs) or
					(nbrNode.parent == current and nbrNode.rhs > rhs)
				then
					nbrNode.rhs = rhs
					nbrNode.parent = current
					self:UpdateVertex(uid, nbrNode)
				end
			end
		else
			local oldG = current.g
			current.g = math.huge
			local nbrs = self:GetNbrs(uid, current) or {}
			for _, nbrNode in pairs(nbrs) do
				if nbrNode.rhs == (oldG + 1) then
					nbrNode.rhs = math.huge
					nbrNode.parent = current
					self:UpdateVertex(uid, nbrNode)
				end
			end
			self:UpdateVertex(uid, current)
		end
	end
end

-- 调试接口：输出路径
function DStarLite:findPath(uid)
	local rData = self:GetRoleData(uid)
	if not rData then
		return
	end

	local mapData = table.deepcopy(self.map_data)
	local key = _GetKey(rData.start.x, rData.start.y)
	local node = rData.openSet[key]
	local n = node
	while n do
		mapData[n.y][n.x] = "E"
		n = n.parent
	end
	-- for key in pairs(self.pos_state) do
	-- 	local x, y = _SplitKey(key)
	-- 	mapData[y][x] = "O"
	-- end

	for y = 1, #mapData do
		local m = ""
		for x = 1, #mapData[1] do
			m = m .. mapData[y][x] .. " "
		end
		print(m)
	end

end








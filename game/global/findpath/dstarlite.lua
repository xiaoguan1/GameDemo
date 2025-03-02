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

function DStarLite:GetRoleData(uid)
	return uid and self.role_data[uid]
end

function DStarLite:GetNode(uid, x, y)
	local key = _GetKey(x, y)
	local rData = self:GetRoleData(uid)
	local node = rData.openSet[key]
	if not node then
		node = {
			x = x,
			y = y,
			g = math.huge,		-- 到目标的实际代价
			rhs = math.huge,	-- 基于邻居的最小代价
			k1 = math.huge,
			k2 = math.huge,
			parent = nil,
		}
	end
	return node
end

function DStarLite:Insert(uid, node)
	local rData = self:GetRoleData(uid)
	local k1, k2 = self:CalcKey(uid, node.x, node.y)
	node.k1, node.k2 = k1, k2
	rData.openList:Push(node)
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
	self:Insert(uid, gNode)
	return rData
end

-- 计算节点的优先级键值
function DStarLite:CalcKey(uid, x, y)
	local rData = self:GetRoleData(uid)
	local node = self:GetNode(uid, x, y)
	local k2 = math.min(node.g, node.rhs)
	local k1 = k2 + _Heuristic(rData.start, node) + rData.km
	return k1, k2
end

function DStarLite:IsWalk(x, y)
	local state = self.map_data[y] and self.map_data[y][x]
	return state == POS_STATE1
end

-- 获取邻居
function DStarLite:GetNbrs(x, y)
	local nbrs = {}
	for _, v in pairs(DIRS) do
		local nbrx = x + v[1]
		local nbry = y + v[2]
		if self:IsWalk(nbrx, nbry) then
			table.insert(nbrs, {x=nbrx, y=nbry})
		end
	end
	return nbrs
end

-- 主计算循环
function DStarLite:ComputePath(uid)
	local rData = self:GetRoleData(uid)
	if not rData then return end

	while true do
		local node = rData.openList:Pop()
		if not node then
			break
		end

		local k1, k2 = node.k1, node.k2
		local sk1, sk2 = self.CalcKey(uid, rData.start.x, rData.start.y)
		if (k1 > sk1) or (k1 == sk1 and k2 > sk2) then
			self:Insert(uid, )
		end



		if node.x == rData.start.x and node.y == rData.start.y then
			-- 到达终点
			break
		end

		if node.g > node.rhs then
			node.g = node.rhs
			local nbrs = self:GetNbrs(node.x, node.y)
			for _, nbr in ipairs(nbrs) do
				if s ~= u then
					if s.rhs > u.g + self:_cost(s, u) then
						s.rhs = u.g + self:_cost(s, u)
						self.U:insert(s, self:_calculateKey(s))
					end
				end
			end
		else

		end


	end
end










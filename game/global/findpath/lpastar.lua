-- https://github.com/xwnb/motion_planning/blob/master/doc/LPA_STAR.md
-- https://blog.csdn.net/qq_44339029/article/details/126789410

local minheap = require "minheap"
local math = math

local DIRS = {
	-- 上，下，左、右
	{0, 1}, {0, -1}, {-1, 0}, {1, 0},
	{1, 1}, {1, -1}, {-1, -1}, {-1, 1},
}

-- 节点移动代价
local MOVECOST = 1

-- 0：障碍、1：可行走
local POS_TYPE0 = 0
local POS_TYPE1 = 1

-- 局部函数 ---------------------------------
-- 启发式函数（切比雪夫距离）
local function _GetKey(x, y)
	return x << 8 | y
end
local function _SplitKey(key)
	local x = key >> 8
	local y = key & 255
	return x, y
end

-- 启发式函数（切比雪夫距离）
local function _Heuristic(a, b)
	local dx = math.abs(a.x - b.x)
	local dy = math.abs(a.y - b.y)
	return math.max(dx, dy)
end


-- LPA Star 类 ---------------------------------
LpaStar = {}
function LpaStar:New(map_data)
	local o = {
		map_data = map_data,	-- 地图配置
		map_modify = {},		-- 地图修改（判断坐标状态优先以它为准，其次以map_data为准）

		role_data = {},			-- 玩家寻路路径数据
	}
	setmetatable(o, {__index = self})
	return o
end

function LpaStar:GetRoleData(uid)
	return uid and self.role_data[uid]
end

function LpaStar:AddRoleEvent(uid, start, goal)
	local rData = self:GetRoleData(uid)
	if not uid or rData then
		_ERROR_F("please not repeat add data, uid: start:%s goal:%s", uid, start, goal)
		return
	end

	rData = {
		uid = uid,
		start = table.copy(start),
		goal = table.copy(goal),
		moveTime = nil,					-- 开始移动时间
		current = nil,					-- 玩家当前位置

		-- minheap：优先队列(最小堆)
		openList = minheap:New("key", {"k1", "k2"}, true),
		openSet = {},
		-- closeList = {},
		pathList = {},	-- 计算后，生成的路径。
	}
	self.role_data[uid] = rData
	local gNode = self:GetNode(uid, goal.x, goal.y)
	gNode.rhs = 0
	rData.openList:Push(gNode)
	return rData
end

function LpaStar:GetNode(uid, x, y)
	local key = _GetKey(x, y)
	local rData = self:GetRoleData(uid)
	local node = rData.openSet[key]
	if not node then
		node = {
			key = key,
			x = x,
			y = y,
			g = math.huge,
			rhs = 0,
			k1 = 0,
			k2 = 0,
			parent = nil,
		}
		rData.openSet[key] = node
	end
	return node
end

function LpaStar:IsWalk(x, y)
	local key = x and y and _GetKey(x, y)
	if not key then return end
	local state = self.map_modify[key]
	if not state then
		state = self.map_data[y] and self.map_data[y][x]
	end
	return state == POS_TYPE1
end


function LpaStar:GetNbrList(uid, node)
	local rData = uid and self:GetRoleData(uid)
	if not rData or not node then
		return
	end
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

function LpaStar:UpdateKey(uid, node)
	local rData = uid and self:GetRoleData(uid)
	if not rData or not node then
		return
	end
	node.k1 = math.min(node.g, node.rhs) + _Heuristic(node, rData.start)
	node.k2 = math.min(node.g, node.rhs)
	return node.k1, node.k2
end

function LpaStar:UpdateVertex(uid, node)
	local rData = uid and self:GetRoleData(uid)
	if not rData or not node then
		return
	end

	if not (node.x == rData.goal.x and node.y == rData.goal.y) then
		local newRhs = math.huge
		for _, nbr in pairs(self:GetNbrList(uid, node) or {}) do
			local tmpRhs = nbr.g + MOVECOST
			if tmpRhs < newRhs then
				newRhs = tmpRhs
				node.parent = nbr.key
			end
		end
		node.rhs = newRhs
	end

	if rData.openList:HasUnique(node.key) then
		rData.openList:Remove(node.key)
	end
	if node.g ~= node.rhs then
		self:UpdateKey(uid, node)
		rData.openList:Push(node)
	end
end

function LpaStar:ComputeShortestPath(uid)
	local rData = uid and self:GetRoleData(uid)
	if not rData then return end

	local startNode = self:GetNode(uid, rData.start.x, rData.start.y)
	local openList = rData.openList
	while openList:Size() > 0 do
		local top = openList:Pop()
		self:UpdateKey(uid, startNode)
		self:UpdateKey(uid, top)
		if not (top.k1 < startNode.k1 or startNode.rhs ~= startNode.g) then
			return
		end
		if top.g > top.rhs then
			top.g = top.rhs
			for _, nbr in pairs(self:GetNbrList(uid, top) or {}) do
				self:UpdateVertex(uid, nbr)
			end
		else
			top.g = math.huge
			self:UpdateVertex(uid, top)
			for _, nbr in pairs(self:GetNbrList(uid, top) or {}) do
				self:UpdateVertex(uid, nbr)
			end
		end
	end
end

-- 动态更新地图
function LpaStar:UpdateMap(x, y, isObs)
	if not (x and y and self.map_data[y] and self.map_data[y][x]) then
		return
	end
	local key = _GetKey(x, y)
	local nPosType = isObs and POS_TYPE0 or POS_TYPE1
	local oPosType = self.map_modify[key] or self.map_data[y][x]
	if oPosType == nPosType then
		return
	end
	if self.map_modify[key] then
		self.map_modify[key] = nil
	else
		self.map_modify[key] = nPosType
	end
	-- if nPosType ~= POS_TYPE0 then
	-- 	-- 非障碍则结束
	-- 	return
	-- end
	for uid, rData in pairs(self.role_data) do
		local node = self:GetNode(uid, x, y)
		node.g = math.huge
		node.rhs = math.huge
		for _, nbr in pairs(self:GetNbrList(uid, node) or {}) do
			if nbr.parent == node.key then
				nbr.parent = nil
				self:UpdateVertex(uid, nbr)
			end
		end
		self:ComputeShortestPath(uid)
	end
end

function LpaStar:OutPutPath(uid)
	local rData = self:GetRoleData(uid)
	if not rData then return end

	-- 生成新的路径
	local pathList = {}
	local node = self:GetNode(uid, rData.start.x, rData.start.y)
	while node do
		table.insert(pathList, {x = node.x, y = node.y})
		if not node.parent then
			break
		end
		node = self:GetNode(uid, _SplitKey(node.parent))
	end
	rData.pathList = pathList
	rData.openList:Clear()
end

-- 打印玩家路径
function LpaStar:Print(uid)
	local rData = self:GetRoleData(uid)
	if not rData then return end
	local mapData = table.deepcopy(self.map_data)
	for key, v in pairs(self.map_modify) do
		if v == POS_TYPE0 then
			local x, y = _SplitKey(key)
			mapData[y][x] = "O"
		elseif v == POS_TYPE1 then
			local x, y = _SplitKey(key)
			mapData[y][x] = "1"
		end
	end

	for _, v in pairs(rData.pathList) do
		mapData[v.y][v.x] = "E"
	end

	for y = 1, #mapData do
		local m = ""
		for x = 1, #mapData[1] do
			m = m .. mapData[y][x] .. " "
		end
		print(m)
	end
	print()
end
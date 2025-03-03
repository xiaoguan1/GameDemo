-- https://blog.csdn.net/mkr67n/article/details/106031055
-- https://github.com/Bastiantheone/DStarLite/blob/master/DStarLite.cs


local minheap = require "minheap"
local math = math

-- 0：障碍、1：可行走
local POS_TYPE0 = 0
local POS_TYPE1 = 1

local DIRS = {
	-- 上，下，左、右
	{0, 1}, {0, -1}, {-1, 0}, {1, 0},
	{1, 1}, {1, -1}, {-1, -1}, {-1, 1},
}

-- 节点状态
local NODE_STATE = { NEW = 1, OPEN = 2, CLOSED = 3, }

-- 节点移动代价
local MOVECOST = 1

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
		map_data = map_data,	-- 地图配置
		map_modify = {},		-- 地图修改（判断坐标状态优先以它为准，其次以map_data为准）

		role_data = {},	-- 玩家寻路路径数据
	}
	setmetatable(o, {__index = self})
	return o
end

-- 计算从当前节点到相邻节点的实际移动成本
function DStarLite:Cost(a, b)
	if not (self:IsWalk(a.x, a.y) and self:IsWalk(b.x, b.y)) then
		return math.huge
	end
	for _, v in pairs(DIRS) do
		if (a.x + v[1]) == b.x and (a.y + v[2]) == b.y then
			-- 相邻节点，默认移动成本为1
			return MOVECOST
		end
	end
end

function DStarLite:IsWalk(x, y)
	local key = x and y and _GetKey(x, y)
	if not key then return end
	local state = self.map_modify[key]
	if not state then
		state = self.map_data[y] and self.map_data[y][x]
	end
	return state == POS_TYPE1
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
			state = NODE_STATE.NEW,
		}
		rData.openSet[key] = node
	end
	return node
end

function DStarLite:UpdateVertex(uid, node)
	-- 当检测到结点G!=Rhs时会将其加入队列（若已在队列中则进行Key更新）
	-- 否则将其从队列中移除
	local rData = self:GetRoleData(uid)
	if not rData then return end
	local isQueue = rData.openList:HasUnique(node.key)
	if node.rhs ~= node.g then
		node.k1, node.k2 = self:CalcKey(uid, node)
		node.state = NODE_STATE.OPEN
		if isQueue then
			rData.openList:Modify(node)
		else
			rData.openList:Push(node)
		end
	else
		if isQueue then
			node.state = NODE_STATE.CLOSED
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
		current.state = NODE_STATE.CLOSED
		if current.x == startX and current.y == startY then
			-- 到达终点
			break
		end

		local k1, k2 = self:CalcKey(uid, current)
		if max_steps == 99998 then
			print(tool.dumptree(current))
			print(k1, k2)

		end
		if current.k1 < k1 or (current.k1 == k1 and current.k2 < k2) then
			current.k1 = k1
			current.k2 = k2
			current.state = NODE_STATE.OPEN
			rData.openList:Push(current)
		elseif current.g > current.rhs then
			-- 局部过一致！意味着该节点的连通状态比之前的要好。
			current.g = current.rhs
			local nbrs = self:GetNbrs(uid, current) or {}
			for _, node in pairs(nbrs) do
				local rhs = math.min(node.rhs, self:Cost(node, current) + current.g)
				if node.state == NODE_STATE.NEW or
					(node.parent == current.key and node.rhs ~= rhs) or
					(node.parent ~= current.key and node.rhs > rhs)
				then
					node.rhs = rhs
					node.parent = current.key
					self:UpdateVertex(uid, node)
				end
			end
		elseif current.g < current.rhs then
			-- 局部欠一致！意味着受到附近新障碍物的直接/间接影响。
			local oldG = current.g
			current.g = math.huge
			local nbrs = self:GetNbrs(uid, current) or {}
			table.insert(nbrs, current)
			for _, node in pairs(nbrs) do
				if node.rhs == (self:Cost(node, current) + oldG) then
					if not (node.x == rData.goal.x and node.y == rData.goal.y) then
						node.rhs = math.huge
					end
					for _, v in pairs(self:GetNbrs(uid, node) or {}) do
						v.rhs = math.min(v.rhs, self:Cost(node, v) + v.g)
					end
					node.parent = current.key
					self:UpdateVertex(uid, node)
				end
			end
			self:UpdateVertex(uid, current)
		end
	end
end

-- 修改地图（设置障碍 or 清除障碍）
function DStarLite:modifyMap(x, y, isObs)
	if not (x and y and self.map_data[y] and self.map_data[y][x]) then
		return
	end
	local nPosType = isObs and POS_TYPE0 or POS_TYPE1
	local key = _GetKey(x, y)
	local oPosType = self.map_modify[key] or self.map_data[y][x]
	if oPosType == nPosType then
		return
	end
	if self.map_modify[key] then
		self.map_modify[key] = nil
	else
		self.map_modify[key] = nPosType
	end
	for uid, rData in pairs(self.role_data) do
		local pathList = self:GetPathList(uid)
		if table.has_value(pathList, key) then
			local node = self:GetNode(uid, x, y)
			if nPosType == POS_TYPE0 then
				node.rhs = math.huge
			end

			local startNode = self:GetNode(uid, rData.start.x, rData.start.y)
			rData.km = rData.km + _Heuristic(startNode, node)
			local nbrs = self:GetNbrs(uid, node) or {}
			for _, v in pairs(nbrs) do
				if not (v.x == startNode.x and v.y == startNode.y) then
					v.rhs = math.min(v.rhs, self:Cost(v, node) + node.g)
					self:UpdateVertex(uid, v)
				end
			end
			self:UpdateVertex(uid, node)
			self:ComputePath(uid)
		end
	end
end

function DStarLite:GetPathList(uid)
	local rData = self:GetRoleData(uid)
	if not rData then
		return
	end
	local path = {}
	local node = self:GetNode(uid, rData.start.x, rData.start.y)
	while node do
		table.insert(path, node.key)
		if node.parent then
			local x, y = _SplitKey(node.parent)
			node = self:GetNode(uid, x, y)
		else
			break
		end
	end
	return path
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
		local key = n.parent
		n = key and rData.openSet[key]
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








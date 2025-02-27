-- 资料来源：
--	https://www.cnblogs.com/MyStringIsNotNull/p/16273574.html
-- 	https://blog.csdn.net/qq_44339029/article/details/127490956
--  https://blog.csdn.net/weixin_42875283/article/details/124341524?spm=1001.2014.3001.5501

-- D星寻路算法虽然解决了动态障碍的问题，但是依然存在一些问题（例如：死路缺陷、网格数和计算量同步递增）

local minheap = require "minheap"
local table = table

local MAPTYPE0 = 0		-- 障碍
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
	-- k：表示当前(x, y)最小的h值
	-- h：表示当前(x, y)坐标到达目标节点(即goal)的代价
	-- parent：表示当前(x, y)节点的父节点
	return {
		key = _GetKey(x, y),
		x = x,
		y = y,
		state = STATE.NEW,
		h = 0,
		k = math.huge,
		parent = nil,
	}
end

-- D星算法的类模板
DStar = { ClassType = "DStar" }
function DStar:New(map_data)
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
	if not self:IsValid(x, y) then
		return
	end
	if isObs then
		self:AddObs(x, y)
	else
		self:SubObs(x, y)
	end

	for uid, rdata in pairs(self.role_data) do
		local node = rdata.openSet[_GetKey(x, y)]
		if node then
			local neighbors = self:CalcNeighbors(uid, x, y) or {}
			for _, nbr in pairs(neighbors) do
				local cost = self:CalcCost(node.x, node.y, nbr.x, nbr.y)
				if nbr.state == STATE.CLOSED then
					self:Insert(uid, nbr, cost)
				end
			end
		end
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
				nbr = _CreateNode(nbrx, nbry)
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
	local node = obj.openList:Pop()
	if not node then
		return
	end
	node.state = STATE.CLOSED

	-- 传播
	if node.k < node.h then
		-- 当h值大于k值时，表示当前该节点处于h值被修改为较大的状态(raise状态)
		-- 为此查找邻居节点来得到减低自身的h值
		--（注释：若h>k,记为Raise态，当该节点处于Raise态时表明有更优的路径。）
		local neighbors = self:CalcNeighbors(uid, node.x, node.y) or {}
		for _, nbr in pairs(neighbors) do
			local cost = self:CalcCost(node.x, node.y, nbr.x, nbr.y)
			local h = nbr.h + cost
			if node.k > nbr.h and node.h > h then
				node.parent = nbr
				node.h = h
			end
		end
	end

	-- 该过程类似于dijikstra，用来传播信息当前节点h值变化的信息和降低邻居节点的h值
	local neighbors = self:CalcNeighbors(uid, node.x, node.y) or {}
	if node.k == node.h then
		for _, nbr in pairs(neighbors) do
			local cost = self:CalcCost(node.x, node.y, nbr.x, nbr.y)
			if nbr.state == STATE.NEW or
				(nbr.parent == node and nbr.h ~= (node.h + cost)) or
				(nbr.parent ~= node and nbr.h > (node.h + cost))
			then
				nbr.parent = node
				self:Insert(uid, nbr, node.h + cost)
			end
		end
	else
		-- k值和h值不相同，表示节点处于调整状态
		for _, nbr in pairs(neighbors) do
			local cost = self:CalcCost(node.x, node.y, nbr.x, nbr.y)
			if nbr.state == STATE.NEW or
				(nbr.parent == node and nbr.h ~= node.h + cost)
			then
				nbr.b = x
				self:Insert(uid, nbr, node.h + cost)
			else
				-- 邻居节点存在更短的路径
				-- 调整当前节点并重新传播当前节点的h值变化信息给周围节点
				if nbr.parent ~= node and (nbr.h > node.h + cost) then
					self:Insert(node, node.h)
				else
					-- 传播邻居节点的信息，使其可以影响当前节点进而修改当前节点的h值和路径信息
					-- 因为这里存在比当前节点的h值更低的值
					if (nbr.parent ~= node and node.h > (nbr.h + cost) and nbr.state == STATE.CLOSED and nbr.h > node.k) then
						self:Insert(uid, nbr, nbr.h)
					end
				end
			end
		end
	end

	return obj.openList:Size()
end

function DStar:Insert(uid, node, newH)
	local obj = self:GetRoleData(uid)
	if not obj then return end

	if node.state == STATE.NEW then
		node.h = newH
		node.k = newH
		node.state = STATE.OPEN
		obj.openList:Push(node)
	elseif node.state == STATE.OPEN then
		node.k = math.min(node.k, newH)
		obj.openList:ModifyByUnique(node)
	else
		node.k = math.min(node.h, newH)
		node.h = newH
		node.state = STATE.OPEN
		obj.openList:Push(node)
	end
end

-- 添加寻路数据
function DStar:CreateFindPath(uid, start, goal)
	local r = self:GetRoleData(uid)
	assert(not r, string.format("uid:%s already has data", uid))

	local r = {
		uid = uid,
		start = table.copy(start),
		goal = table.copy(goal),
		current = table.copy(start),

		-- minheap：优先队列(最小堆)
		-- openList：存放节点状态为OPEN的节点。且其按照节点的k值从小到大进行排序
		openList = minheap:New("key", {"k"}, true),
		openSet = {},
	}
	self.role_data[uid] = r

	local goalNode = _CreateNode(goal.x, goal.y)
	goalNode.h, goalNode.k = 0, 0
	goalNode.state = STATE.OPEN
	r.openSet[goalNode.key] = goalNode
	r.openList:Push(goalNode)
	return r
end

-- 调试接口：输出路径
function DStar:findPath(uid)
	local rData = self:GetRoleData(uid)
	if not rData then
		return
	end

	local key = _GetKey(rData.start.x, rData.start.y)
	local node = rData.openSet[key]
	local n = node
	while n do
		print(n.x, n.y)
		n = n.parent
	end
end
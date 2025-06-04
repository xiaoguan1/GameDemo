-- 跳点式的A星寻路（简称jps）
local table = table
local utf8 = utf8

-- 四边形的方向配置
local DIRECTION_4 = {
	{x = 0, y = 1}, {x = 0, y = -1}, -- 上、下
	{x = -1, y = 0}, {x = 1, y = 0}, -- 左、右
	{x = 1, y = 1}, {x = 1, y = -1}, -- 右上、右下
	{x = -1, y = 1}, {x = -1, y = -1}, -- 左上、左下
}
assert(#DIRECTION_4 == table.size(DIRECTION_4))

-- 坐标位置的特性
local POS_STATE0 = 0	-- 障碍
local POS_STATE1 = 1	-- 正常可行走

local BYTE_SIZE = 8
local function _Key(x, y)
	return x << BYTE_SIZE | y
end
local function _RKey(key)
	local x = key >> BYTE_SIZE
	local y = key ~ (x << BYTE_SIZE)
	return x, y
end

local function _CNode(x, y)
	assert(x and y)
	return {
		x = x,
		y = y,
		key = _Key(x, y),
		pkey = nil, -- 父节点的key值
		h = 0,
		g = 0,
		f = 0,
	}
end

-- 判断父坐标p 和 子坐标s 的移动方向
local function _CalcDir(p, s)
	assert(p and s)
	local diff = s - p
	if diff > 0 then
		-- 前进
		return 1
	elseif diff < 0 then
		-- 后退
		return -1
	end
	return 0
end

-- 预估值（曼哈顿距离）
local function _CalcH(x, y, goalX, goalY)
	return math.abs(goalX - x) + math.abs(goalY - y)
end

local function _CompareF(p1, p2)
	if p1.f < p2.f then
		return true
	elseif p1.f == p2.f and p1.g < p2.g then
		return true
	end
end

-- 输出路径
local function _PrintPath(closeList, node)
	local path = ""
	while node do
		path = path .. string.format("(%s, %s) <-", node.x, node.y)
		node = node.pkey and closeList[node.pkey]
	end
	print(path)
end

-- 类
Mapping = { __ClassType = "<<mapping class>>" }

-- 坐标是否有效
function Mapping:IsValid(x, y)
	return x and y and self.data[x] and self.data[x][y]
end

function Mapping:IsWalk(x, y)
	local state = x and y and self.data[x] and self.data[x][y]
	return state == POS_STATE1
end

function Mapping:IsObs(x, y)
	local state = x and y and self.data[x] and self.data[x][y]
	return state == POS_STATE0
end

function Mapping:CalcNeighbors(node)
	node = node or {}
	if not self:IsWalk(node.x, node.y) then
		return
	end
	local neighbs = {}
	local x, y = node.x, node.y

	if not node.pkey then
		-- 父节点为空，起点或者目标点！
		for _, v in ipairs(DIRECTION_4) do
			local nextX, nextY = (x + v.x), (y + v.y)
			if self:IsWalk(nextX, nextY) then
				table.insert(neighbs, {x = nextX, y = nextY})
			end
		end
		return neighbs
	end

	local px, py = _RKey(node.pkey)
	local xDir, yDir = _CalcDir(px, x), _CalcDir(py, y)
	local nextX, nextY = x + xDir, y + yDir
	local preX, preY = x - xDir, y - yDir
	if xDir ~= 0 and yDir ~= 0 then
		-- 简化问题：
		-- 		1.斜方向移动可以分解成两个移动方向向量！例如 "右上斜方向" 移动可，可以分解成右方、上方。
		--		  又因为斜方向包含 右上、左上、右下、左下 四个斜方向！而为了抽象出这一部分的逻辑，
		-- 		  故在变量命名上假设它是右上斜方向移动！特别注意：方向上的移动要严格的使用 xDir 和 yDir
		-- 		2：xDir 和 yDir 的取值是 -1 或者 1

		local upWalk = self:IsWalk(x, nextY)
		local rightWalk = self:IsWalk(nextX, y)
		local downWalk = self:IsWalk(x, preY)
		local leftWalk = self:IsWalk(preX, y)

		-- 正前方是否可行走
		if self:IsWalk(nextX, nextY) then
			table.insert(neighbs, {x = nextX, y = nextY})
		end

		-- 斜方向的两个方向分量
		if upWalk then
			table.insert(neighbs, {x = x, y = nextY})
		end
		if rightWalk then
			table.insert(neighbs, {x = nextX, y = y})
		end

		-- 两个强迫邻居
		if not leftWalk and self:IsWalk(preX, nextY) then
			table.insert(neighbs, {x = preX, y = nextY})
		end
		if not downWalk and self:IsWalk(nextX, preY) then
			table.insert(neighbs, {x = nextX, y = preY})
		end
	elseif xDir ~= 0 then
		-- 横向（因为yDir为0，故nextY和y的值一样）
		if self:IsWalk(nextX, y) then
			table.insert(neighbs, {x = nextX, y = y})
		end
		local upY, downY = y + 1, y - 1
		local upWalk = self:IsWalk(x, upY)
		local downWalk = self:IsWalk(x, downY)
		if not upWalk and self:IsWalk(nextX, upY) then
			table.insert(neighbs, {x = nextX, y = upY})
		end
		if not downWalk and self:IsWalk(nextX, downY) then
			table.insert(neighbs, {x = nextX, y = downY})
		end
	elseif yDir ~= 0 then
		-- 纵向（因为xDir为0，故nextX和x的值一样）
		local rightX, leftX = x + 1, x - 1
		local rightWalk = self:IsWalk(rightX, y)
		local leftWalk = self:IsWalk(leftX, y)
		if self:IsWalk(x, nextY) then
			table.insert(neighbs, {x = x, y = nextY})
		end
		if not leftWalk and self:IsWalk(leftX, nextY) then
			table.insert(neighbs, {x = leftX, y = nextY})
		end
		if not rightWalk and self:IsWalk(rightX, nextY) then
			table.insert(neighbs, {x = rightX, y = nextY})
		end
	else
		error("calc neighbors fail")
	end

	return neighbs
end

-- a星寻路（核心逻辑）
function Mapping:AStart(startX, startY, goalX, goalY)

end

-- jsp寻路（核心逻辑）
function Mapping:Jsp(startX, startY, goalX, goalY)
	assert(self:IsValid(startX, startY) and self:IsValid(goalX, goalY))

	-- 这里缺少了洪水填充，判断两个坐标点是否处于同一片区域！

	-- 待检测节点列表、辅助节点列表、已检测节点列表
	local openList, openSet, closeList = {}, {}, {}
	local startNode = _CNode(startX, startY)
	table.insert(openList, startNode)
	openSet[startNode.key] = startNode

	local function _SeekJumpPoint(x, y, xDir, yDir)
		assert(x and y and xDir and yDir)
		if not (self:IsWalk(x, y) and
			(xDir >= -1 and xDir <= 1) and (yDir >= -1 and yDir <= 1) and
			(xDir ~= 0 or yDir ~= 0))
		then
			return
		end

		-- 条件1：位置节点是起始点或目标点
		if x == goalX and y == goalY then
			return {x = x, y = y}
		end

		-- 条件2：位置节点至少有一个强迫邻居
		local nextX, nextY = x + xDir, y + yDir
		local preX, preY = x - xDir, y - yDir
		if xDir ~= 0 and yDir ~= 0 then
			if (self:IsWalk(nextX, preY) and not self:IsWalk(x, preY)) or
				(self:IsWalk(preX, nextY) and not self:IsWalk(preX, y))
			then
				return {x = x, y = y}
			end
		elseif yDir ~= 0 then
			if (self:IsWalk(x - 1, nextY)) and not self:IsWalk(x - 1, y) or
				(self:IsWalk(x + 1, nextY) and not self:IsWalk(x + 1, y))
			then
				return {x = x, y = y}
			end
		else
			if (self:IsWalk(nextX, y + 1) and not self:IsWalk(x, y + 1)) or
				(self:IsWalk(nextX, y - 1) and not self:IsWalk(x, y - 1))
			then
				return {x = x, y = y}
			end
		end

		-- 条件3：如果位置节点x。父节点到位置节点x是对角移动(即xDir和yDir均不为0)，
		--			且x可以通过水平或者垂直方向的移动到达另一个跳点，则节点x也是跳点。
		if xDir ~= 0 and yDir ~= 0 then
			local isOk1 = _SeekJumpPoint(nextX, y, xDir, 0)
			local isOk2 = _SeekJumpPoint(x, nextY, 0, yDir)
			if isOk1 or isOk2 then
				return {x = x, y = y}
			end
		end

		-- 未寻找到跳点，继续沿着既定的方向前进
		if self:IsWalk(nextX, nextY) then
			return _SeekJumpPoint(nextX, nextY, xDir, yDir)
		end
	end

	while #openList > 0 do
		local current = table.remove(openList, 1)
		openSet[current.key] = nil
		closeList[current.key] = current
		if current.x == goalX and current.y == goalY then
			_PrintPath(closeList, current)
			return
		end

		local jumpPoints = {}
		local neighbs = self:CalcNeighbors(current) or {}
		for _, v in ipairs(neighbs) do
			local xDir, yDir = _CalcDir(current.x, v.x), _CalcDir(current.y, v.y)
			local point = _SeekJumpPoint(v.x, v.y, xDir, yDir)
			if point then
				table.insert(jumpPoints, point)
			end
		end

		local newG = current.g + 1
		for _, v in ipairs(jumpPoints) do
			local key = _Key(v.x, v.y)
			if not closeList[key] then
				local existV = openSet[key]
				if existV then
					if existV.g > newG then
						existV.g = newG
						existV.f = existV.g + existV.h
						existV.pkey = current.key
					end
				else
					local node = _CNode(v.x, v.y)
					node.g = newG
					node.h = _CalcH(v.x, goalX, v.y, goalY)
					node.f = node.g + node.h
					node.pkey = current.key
					table.insert(openList, node)
					openSet[node.key] = node
					table.sort(openList, _CompareF)
				end
			end
		end
	end
end

-- 初始化
function Mapping:Test1()
	local mapData = {
		"############################################################",
		'#..........................................................#',
		'#.............................#............................#',
		'#.............................#............................#',
		'#.............................#............................#',
		'#.............................#............................#',
		'#.............................#............................#',
		'#.............................#............................#',
		'#.............................#............................#',
		'#.............................#............................#',
		'#.............................#............................#',
		'#.............................#............................#',
		'#.............................#............................#',
		'#######.#######################################............#',
		'#....#........#............................................#',
		'#....#...S....#............................................#',
		'#....##########............................................#',
		'#..........................................................#',
		'#..........................................................#',
		'#..........................................................#',
		'#..........................................................#',
		'#..........................................................#',
		'#...............................##############.............#',
		'#...............................#............#.............#',
		'#...............................#............#.............#',
		'#...............................#....####....#.............#',
		'#...............................#....#.E...................#',
		'#...............................##############.............#',
		'#..........................................................#',
		'#..........................................................#',
		'############################################################',
	}
	assert(table.size(mapData) == #mapData, "mapData len error")

	local o = {
		__IsObject = os.time(),
		obsList = { -- 障碍坐标
			-- [x] = y
		},
		data = {	-- 地图数据
			-- [x] = { [y] = state, ... }	state（0：障碍、1：可行走）
		},
	}
	local start, goal = nil, nil
	for y = 1, #mapData do
		for x, byte in utf8.codes(mapData[y]) do
			local c = utf8.char(byte)
			local state = POS_STATE1
			if c == "#" then
				state = POS_STATE0
			elseif c == "S" then
				start = {x = x, y = y}
			elseif c == "E" then
				goal = {x = x, y = y}
			end
			o.data[x] = o.data[x] or {}
			o.data[x][y] = state
		end
	end

	print(string.format("起始和目标点坐标信息 (%s, %s) --> (%s, %s)",
		start.x, start.y, goal.x, goal.y))

	setmetatable(o, {__index = self})
	o:Jsp(start.x, start.y, goal.x, goal.y)


end






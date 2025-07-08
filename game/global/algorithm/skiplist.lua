-- 跳表
local ostime = os.time
local mrandom = math.random
local tsize = table.size
local type = type
local RANDOM_MAX = 10000
local SKIPLIST_P = 2500
local SKIPLIST_MAXLEVEL = 32
local tdeepcopy = table.deepcopy
local sformat = string.format
local tempty = table.empty

local function _RandomLevel()
	local level = 1
	while level < SKIPLIST_MAXLEVEL and mrandom(RANDOM_MAX) < SKIPLIST_P do
		level = level + 1
	end
	return level
end

SkipList = { __ClassType = "<<skiplist class>>" }

local function _CreateNode(data)
	assert(data)
	return {
		forward = {},			-- 前驱指针
		backward = {},			-- 后继指针数组
		data = tdeepcopy(data),
		level = _RandomLevel(),
	}
end

function SkipList:New(uniqueKey, sortKeys, orders, maxLength)
	assert(type(uniqueKey) == "string" and uniqueKey:len() > 0)
	assert(type(sortKeys) == "table" and #sortKeys > 0 and #sortKeys == tsize(sortKeys))
	assert(type(maxLength) == "number" and maxLength > 0)

	local norders = {}
	for k, v in pairs(sortKeys) do
		if type(v) ~= "string" then
			error("sortKey type not string key " .. v)
		end
		local isDesc = orders[k]
		norders[k] = isDesc and true or false	-- true:降序、false:升序
	end

	local o = {
		__SuperClass = self,			-- 标记RoleClass为父类
		__IsObject = ostime(),			-- 标记为实例对象
		linkData = {					-- 带头节点的链表
			isHead = true,
			backward = {},				-- 后继指针数组
		},

		key2Rank = {},				-- 排名（数组）
		rankList = {},
		key2Node = {},					-- uniqueKey 映射 节点

		uniqueKey = uniqueKey,
		length = 0,						-- 当前容量
		maxLength = maxLength,			-- 最大容量限制
		sortKeys = tdeepcopy(sortKeys),	-- 排序的键
		orders = norders,				-- 每个建的升序或降序特性
	}

	setmetatable(o, {__index = self})
	return o
end

-- 比较函数
-- true:newNode 排在 oldNode 前面
function SkipList:CompareFunc(newNode, oldNode)
	for i = 1, #self.sortKeys do
		local key, isDesc = self.sortKeys[i], self.orders[i]
		local val1, val2 = newNode[key], oldNode[key]
		if isDesc then
			-- 降序
			if val1 ~= val2 then
				return val1 > val2
			end
		else
			-- 升序
			if val1 ~= val2 then
				return val1 < val2
			end
		end
	end
	return false
end

function SkipList:GetuUniqueKey()
	return self.uniqueKey
end

function SkipList:GetSortKeys()
	return self.sortKeys
end

function SkipList:GetNodeByKey(unique)
	return unique and self.key2Node[unique]
end

function SkipList:SetKey2Node(key, node)
	self.key2Node[key] = node
	if node then
		self.length = self.length + 1
	else
		self.length = self.length - 1
	end
	self.length = self.length > 0 and self.length or 0
end

function SkipList:IsFull()
	return self.length >= self.maxLength
end

function SkipList:UpdateRank()
	local rankList, key2Rank = {}, {}
	local curr = self.linkData.backward[1]
	local uniqueKey = self.uniqueKey
	for i = 1, self.length do
		local data = curr and curr.data
		if not data then
			break
		end
		rankList[i] = data[uniqueKey]
		key2Rank[data[uniqueKey]] = i
		curr = curr.backward[1]
	end
	self.rankList = rankList
	self.key2Rank = key2Rank
end

function SkipList:Find(uniqueKey)
end

function SkipList:Push(data)
	if not data then return end
	local uniqueKey = self:GetuUniqueKey()
	local unique = data[uniqueKey]
	if not unique then
		error("not uniqueKey field " .. uniqueKey)
	end

	if self:GetNodeByKey(unique) then
		error(sformat("repeat same unique:%s", unique))
	end
	for _, key in ipairs(self.sortKeys) do
		if not data[key] then
			error("not sortKey field " .. key)
		end
	end

	if self:IsFull() then
		local lastUnique = self.rankList[#self.rankList]
		assert(lastUnique)
		local lastNode = self:GetNodeByKey(lastUnique)
		if not self:CompareFunc(data, lastNode.data) then
			return
		end
		-- 删除操作
		self:Delete(lastUnique)
		assert(not self:IsFull())
	end

	local newNode = _CreateNode(data)
	local headNode = self.linkData
	local update = {}
	local curr = headNode
	assert(#headNode.backward <= SKIPLIST_MAXLEVEL)
	local maxLoop = self.maxLength + 1
	for i = #headNode.backward, 1, -1 do
		local loop = 0
		while curr.backward[i] and not self:CompareFunc(newNode.data, curr.backward[i].data) do
			loop = loop + 1
			if loop > maxLoop then
				error(sformat("unique:%s loop:%s error!", unique, loop))
			end
			curr = curr.backward[i]
		end
		update[i] = curr
	end

	if newNode.level > #headNode.backward then
		for i = #headNode.backward + 1, newNode.level, 1 do
			update[i] = headNode
		end
	end

	for i = 1, newNode.level do
		local backNode = update[i].backward[i]
		newNode.backward[i] = backNode
		if backNode then
			backNode.forward[i] = newNode
		end
		newNode.forward[i] = update[i]
		update[i].backward[i] = newNode

		-- newNode.backward[i] = update[i].backward[i]
		-- update[i].backward[i] = newNode
	end
	self:SetKey2Node(unique, newNode)
	self:UpdateRank()
end

function SkipList:Delete(unique)
	if not unique then return end
	local node = self:GetNodeByKey(unique)
	if not node then
		return
	end

	local rank = self.key2Rank[unique]
	local forward, backward = node.forward, node.backward
	for i = 1, node.level do
		local fnode = forward[i]
		fnode.backward[i] = backward[i]
	end
	self:SetKey2Node(unique)
	table.remove(self.rankList, rank)
	self.key2Rank[unique] = nil
end



function SkipList:Dump()
	print("uniqueKey: ", self.uniqueKey)
	for k, v in ipairs(self.sortKeys) do
		print(sformat("sortKey:%s  isDesc:%s", v, self.orders[k]))
	end

	local headNode = self.linkData
	local level = headNode.backward and #headNode.backward or 0
	for i = level, 1, -1 do
		local node = headNode.backward[i]
		local context = sformat("level:%s ", i)
		while node do
			context = context .. sformat("uniqueKey:%s -> ", node.data[self.uniqueKey])
			node = node.backward and node.backward[i]
		end
		print(context)
	end

end


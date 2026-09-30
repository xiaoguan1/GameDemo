-- 跳表 guanguowei
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

--- 随机生成节点层数（每层 1/4 概率继续递增）
--- @return number level 层数，范围 [1, SKIPLIST_MAXLEVEL]
local function _RandomLevel()
	local level = 1
	while level < SKIPLIST_MAXLEVEL and mrandom(RANDOM_MAX) < SKIPLIST_P do
		level = level + 1
	end
	return level
end

--- 创建跳表节点
--- @param data table 节点数据（会深拷贝一份存入节点）
--- @param level number|nil 指定层数；为 nil 时随机生成
--- @return table 节点，含 prev/next/data/level 字段
local function _CreateNode(data, level)
	assert(data)
	return {
		prev = {},			-- 前驱指针数组：指向队头方向（名次更靠前）的上一个节点
		next = {},			-- 后继指针数组：指向队尾方向（名次更靠后）的下一个节点
		data = tdeepcopy(data),
		level = level or _RandomLevel(),
	}
end

--- 将节点插入跳表，并维护 key2Node/rankList/key2Rank
--- @param obj table SkipList 实例
--- @param newNode table _CreateNode 创建的节点（data 已含 uniqueKey 与所有 sortKeys 字段）
local function _Insert(obj, newNode)
	assert(obj and obj.__IsObject)
	local headNode = obj.linkData
	local uniqueKey = obj.uniqueKey
	local unique = newNode.data[uniqueKey]
	local update = {}
	local curr = headNode
	assert(#headNode.next <= SKIPLIST_MAXLEVEL)
	local maxLoop = obj.maxLength + 1
	for i = #headNode.next, 1, -1 do
		local loop = 0
		while curr.next[i] and not obj:CompareFunc(newNode.data, curr.next[i].data) do
			loop = loop + 1
			if loop > maxLoop then
				error(sformat("unique:%s loop:%s error!", unique, loop))
			end
			curr = curr.next[i]
		end
		update[i] = curr
	end

	if newNode.level > #headNode.next then
		for i = #headNode.next + 1, newNode.level, 1 do
			update[i] = headNode
		end
	end

	for i = 1, newNode.level do
		local nextNode = update[i].next[i]
		newNode.next[i] = nextNode
		if nextNode then
			nextNode.prev[i] = newNode
		end
		newNode.prev[i] = update[i]
		update[i].next[i] = newNode

		-- newNode.next[i] = update[i].next[i]
		-- update[i].next[i] = newNode
	end
	obj:SetKey2Node(unique, newNode)

	local prevNode = newNode.prev[1]
	if prevNode.isHead then
		table.insert(obj.rankList, 1, unique)
		obj.key2Rank[unique] = 1
		for rank = 2, #obj.rankList do
			obj.key2Rank[obj.rankList[rank]] = rank
		end
	else
		local funique = prevNode.data[uniqueKey]
		local frank = obj.key2Rank[funique]
		table.insert(obj.rankList, frank + 1, unique)
		obj.key2Rank[unique] = frank + 1
		for rank = (frank + 2), #obj.rankList do
			obj.key2Rank[obj.rankList[rank]] = rank
		end
	end
end

SkipList = Class.NewClass("<<skiplist class>>")

--- 创建排行榜跳表实例
--- @param uniqueKey string 唯一标识字段名（如玩家 id），用于判重与查找
--- @param sortKeys table 排序字段名数组（非空，下标 1..n 连续），如 {"score","level"}
--- @param orders table 与 sortKeys 逐位对应的排序方向：true=降序，false/nil=升序
--- @param maxLength number 最大容量，超出后插入时淘汰队尾元素
--- @return table SkipList 实例
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
			next = {},				-- 后继指针数组（头节点只有 next，无 prev）
		},

		key2Rank = {},					-- 排名（unique → 名次，map）
		rankList = {},					-- 排名（名次 → unique，array）
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

--- 比较两个数据的先后：按 sortKeys 顺序逐字段比较，
--- 遇到第一个不相等的字段即按该字段的 orders 方向返回结果
--- @param newData table 待比较的数据表
--- @param oldData table 已存在的数据表
--- @return boolean true 表示 newData 应排在 oldData 前面；全部字段相等返回 false
function SkipList:CompareFunc(newData, oldData)
	for i = 1, #self.sortKeys do
		local key, isDesc = self.sortKeys[i], self.orders[i]
		local val1, val2 = newData[key], oldData[key]
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

--- 获取唯一标识字段名
--- @return string uniqueKey 唯一标识字段名
function SkipList:GetUniqueKey()
	return self.uniqueKey
end

--- 获取排序字段名数组
--- @return table sortKeys 排序字段名数组（引用原对象，勿直接修改）
function SkipList:GetSortKeys()
	return self.sortKeys
end

--- 按唯一键查找节点
--- @param unique any 唯一键值
--- @return table|nil 节点；不存在时返回 nil
function SkipList:GetNodeByKey(unique)
	return unique and self.key2Node[unique]
end

--- 维护 key2Node 映射并同步 length 计数
--- （注意副作用：传 node 则 length+1，传 nil 则 length-1）
--- @param key any 唯一键值
--- @param node table|nil 节点；为 nil 时删除映射并扣减 length
function SkipList:SetKey2Node(key, node)
	self.key2Node[key] = node
	if node then
		self.length = self.length + 1
	else
		self.length = self.length - 1
	end
	self.length = self.length > 0 and self.length or 0
end

--- 判断是否已达容量上限
--- @return boolean true 表示已满
function SkipList:IsFull()
	return self.length >= self.maxLength
end

--- 插入一条排行榜数据；若已满且新数据不如队尾元素优先则直接丢弃
--- @param data table 数据，须含 uniqueKey 字段及所有 sortKeys 字段
function SkipList:Push(data)
	if not data then return end
	local uniqueKey = self:GetUniqueKey()
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

	_Insert(self, _CreateNode(data))
end

--- 删除指定唯一键对应的节点
--- @param unique any 唯一键值
--- @return table|nil 被删除的节点；不存在时返回 nil
function SkipList:Delete(unique)
	if not unique then return end
	local delNode = self:GetNodeByKey(unique)
	if not delNode then
		return
	end

	local rank = self.key2Rank[unique]
	for i = 1, delNode.level do
		local prevNode = delNode.prev[i]   -- 该层上被删节点的前驱（队头方向）
		prevNode.next[i] = delNode.next[i] -- 前驱跳过后继，直接指向被删节点的后继
	end
	self:SetKey2Node(unique)
	for i = rank + 1, #self.rankList do
		self.key2Rank[self.rankList[i]] = i - 1
	end
	table.remove(self.rankList, rank)
	self.key2Rank[unique] = nil
	return delNode
end

--- 修改一条已有数据的排序字段（先删后插，并保留原层数不变）
--- @param data table 新数据，须含 uniqueKey 字段及所有 sortKeys 字段
function SkipList:Modify(data)
	if not data then return end
	local uniqueKey = self:GetUniqueKey()
	local unique = data[uniqueKey]
	if not unique then
		error("not uniqueKey field " .. uniqueKey)
	end

	if not self:GetNodeByKey(unique) then
		error(sformat("please push unique:%s", unique))
	end
	for _, key in ipairs(self.sortKeys) do
		if not data[key] then
			error("not sortKey field " .. key)
		end
	end

	-- 需要保持level不变！！！！
	local delNode = self:Delete(unique)
	if not delNode then
		_ERROR_F("unique:%s modify fail! data:%s", unique, tool.dump(data))
		return
	end
	data = _CreateNode(data, delNode.level)
	_Insert(self, data)
end

--- 打印跳表各层结构及排名信息（调试用）
function SkipList:Dump()
	print("uniqueKey: ", self.uniqueKey)
	for k, v in ipairs(self.sortKeys) do
		print(sformat("sortKey:%s  isDesc:%s", v, self.orders[k]))
	end
	print("\n")

	local headNode = self.linkData
	local level = headNode.next and #headNode.next or 0
	for i = level, 1, -1 do
		local node = headNode.next[i]
		local context = sformat("level:%s ", i)
		while node do
			context = context .. sformat("uniqueKey:%s -> ", node.data[self.uniqueKey])
			node = node.next and node.next[i]
		end
		print(context)
	end
	print("rankList: ", tool.dump(self.rankList))
	print("key2Rank: ", tool.dump(self.key2Rank))
end


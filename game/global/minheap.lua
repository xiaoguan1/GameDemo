-- 最小堆（优先队列）

local table = table
local string = string

local MinHeap = {}
function MinHeap:Swap(aIndex, bIndex)
	local heap = self.heap
	local aNode = heap[aIndex]
	local bNode = heap[bIndex]
	heap[aIndex] = bNode
	heap[bIndex] = aNode
	if aNode then
		self.stub[aNode.unique] = bIndex
	end
	if bNode then
		self.stub[bNode.unique] = aIndex
	end
end

function MinHeap:CompareFunc(son, parent)
	for _, key in pairs(self.sortKeys) do
		local pv, sv = parent.ele, son.ele
		if pv[key] > sv[key] then
			-- 父节点元素大于子节点元素
			return true
		end
	end
end

-- 排序(自下到上排序)
function MinHeap:SideUp(index)
	local size = self:Size()
	if size <= 1 then
		return
	end
	index = index or size
	if not (index > 0 and index <= size) then
		return
	end

	local heap = self.heap
	local loop = 0
	while true do
		loop = loop + 1
		if loop > size then
			error("side up error! loop:" .. loop)
		end

		local smallest = index // 2
		if smallest <= 0 then break end

		local parent = heap[smallest]
		local son = heap[index]

		if not self:CompareFunc(son, parent) then
			break
		end

		self:Swap(index, smallest)
		-- heap[smallest] = heap[index]
		-- heap[index] = parent
		index = smallest
	end
end

-- 排序(自上到下排序)
function MinHeap:SideDown(index)
	local size = self:Size()
	if size <= 1 then
		return
	end

	local loop = 0
	index = index or 1
	while true do
		loop = loop + 1
		if loop > size then
			error("side down error! loop:" .. loop)
		end

		local l = index * 2
		local r = (index * 2) + 1
		local smallest = index
		if l <= size then
			local parent = self.heap[smallest]
			local lSon = self.heap[l]
			if self:CompareFunc(lSon, parent) then
				smallest = l
			end
		end
		if r <= size then
			local parent = self.heap[smallest]
			local rSon = self.heap[r]
			if self:CompareFunc(rSon, parent) then
				smallest = r
			end
		end
		if index == smallest then
			break
		end
		self:Swap(index, smallest)
		-- local parent = self.heap[index]
		-- self.heap[index] = self.heap[smallest]
		-- self.heap[smallest] = parent
		index = smallest
	end
end

function MinHeap:HasUnique(unique)
	for _, v in pairs(self.heap) do
		if v.unique == unique then
			return true
		end
	end
end

function MinHeap:Push(ele)
	local u = ele[self.unique]
	if not u then
		error("not unique field " .. self.unique)
	end

	if self:HasUnique(u) then
		error(string.format("repeat same unique:%s", u))
	end

	for _, key in pairs(self.sortKeys) do
		if not ele[key] then
			error("not sortKey field " .. key)
		end
	end

	local index = self:Size() + 1
	self.heap[index] = {
		unique = u,
		ele = self.isQuote and ele or table.copy(ele),
	}
	-- 更新最小堆
	self:SideUp(index)
end

function MinHeap:GetDataByUnique(unique)
	local index = unique and self.stub[unique]
	if not index then return end
	local ele = self.heap[index] and self.heap[index].ele
	if not ele then return end
	ele = table.copy(v.ele)
	setmetatable(ele, {__newindex = function (...) error("not modify") end})
	return ele
end

-- 这个接口的效率较低（还可以通过旧的排序值进行查找大致的范围，再进行for。）
function MinHeap:ModifyByUnique(modifyEle)
	if not modifyEle then return end
	local unique = modifyEle[self.unique]
	if not unique then
		error(string.format("not unique:%s modifyEle:%s", self.unique, tool.dumptree(modifyEle)))
	end
	for _, key in pairs(self.sortKeys) do
		if not modifyEle[key] then
			error(string.format("not sortKey:%s modifyEle:%s", key, tool.dumptree(modifyEle)))
		end
	end

	local index = unique and self.stub[unique]
	local oldEle = index and self.heap[index]
	if not oldEle then
		error(string.format("not find unique:%s data", unique))
	end
	if not oldEle[self.unique] == modifyEle[self.unique] then
		error("unique must be equal")
	end

	local isGt = self:CompareFunc({ele = modifyEle}, oldEle)
	oldEle.ele = modifyEle
	self.heap[index] = oldEle
	if isGt then
		-- oldEle大于modifyEle, 自上到下排序。
		self:SideDown(index)
	else
		-- oldEle小于modifyEle，自下到上排序
		self:SideUp(index)
	end
end

function MinHeap:GetTopUnique()
	if self:IsEmpty() then
		return
	end
	return self.heap[1] and self.heap[1].unique
end

function MinHeap:GetTop()
	if self:IsEmpty() then
		return
	end
	return self.heap[1]
end

function MinHeap:Clear()
	self.heap = {}
	self.stub = {}
end

-- 最小堆出栈
function MinHeap:Pop()
	if self:IsEmpty() then
		return
	end
	local top = self:GetTop()
	local size = self:Size()
	if size == 1 then
		self:Clear()
	elseif size > 1 then
		self.heap[1] = nil
		self.stub[top.unique] = nil
		self:Swap(1, size)
		self:SideDown()
	end
	return top and top.ele
end

function MinHeap:Size()
	return #self.heap
end

function MinHeap:IsEmpty()
	return self:Size() <= 0
end

-- isQuote:true 引用(不对ele进行复制)
function MinHeap:New(unique, sortKeys, isQuote)
	local st = type(sortKeys)
	assert(type(unique) == "string")
	assert(st == "table" or #sortKeys > 0)
	local cpSortKeys = {}
	for _, key in pairs(sortKeys) do
		if type(key) ~= "string" then
			error("sortKey type not string. key " .. key)
		end
		table.insert(cpSortKeys, key)
	end

	local o = {
		sortKeys = cpSortKeys,
		unique = unique,
		heap = {},
		stub = {},
		isQuote = isQuote,
	}
	setmetatable(o, {__index = self})
	return o
end

return MinHeap

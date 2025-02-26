-- 最小堆（优先队列）

local table = table
local string = string

local MinHeap = {}
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

		heap[smallest] = heap[index]
		heap[index] = parent
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
		local parent = self.heap[index]
		self.heap[index] = self.heap[smallest]
		self.heap[smallest] = parent
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
	if not unique then return end
	for _, v in pairs(self.heap) do
		if v.unique == unique then
			local ele = table.copy(v.ele)
			setmetatable(ele, {__newindex = function (...) error("not modify") end})
			return ele
		end
	end
end

-- 这个接口的效率较低（还可以通过旧的排序值进行查找大致的范围，再进行for。）
function MinHeap:ModifyByUnique(unique, modifyEle)
	if not unique or not modifyEle then
		return
	end
	if modifyEle[self.unique] then
		error("not modify unique:" .. self.unique)
	end
	for _, key in pairs(self.sortKeys) do
		if not modifyEle[key] then
			error("not sortKey field " .. key)
		end
	end

	local k, oldEle
	for _k, v in pairs(self.heap) do
		if v.unique == unique then
			k, oldEle = _k, v
			break
		end
	end
	if not oldEle then
		error("not find unique:" .. unique)
	end

	if self:CompareFunc(modifyEle, oldEle) then
		-- oldEle大于modifyEle, 自上到下排序。
		self:SideDown(k)
	else
		-- oldEle小于modifyEle，自下到上排序
		self:SideUp(k)
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
		self.heap[1] = self.heap[size]
		self.heap[size] = nil
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
		isQuote = isQuote,
	}
	setmetatable(o, {__index = self})
	return o
end

return MinHeap

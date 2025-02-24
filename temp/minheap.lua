-- 最小堆（优先队列）

local table = table
local string = string

local MinHeap = {}

function MinHeap:CompareFunc(son, parent)
	for _, key in pairs(self.sortKeys) do
		local sv = son.ele
		local pv = parent.ele
		if pv[key] > sv[key] then
			-- 父节点元素大于子节点元素
			return true
		end
	end
end

-- 排序(自下到上排序)
function MinHeap:Update(index)
	local size = #self.heap
	if not (index and index > 0 and index <= size) then
		return
	end

	local heap = self.heap
	local loop = 0
	while true do
		loop = loop + 1
		if loop > size then break end

		local pIndex = index // 2
		if pIndex <= 0 then break end

		local parent = heap[pIndex]
		local son = heap[index]

		if not self:CompareFunc(son, parent) then
			break
		end

		heap[pIndex] = heap[index]
		heap[index] = parent
		index = pIndex
	end
end

-- 排序(自上到下排序)
function MinHeap:UpdateEx()
	local size = #self.heap
	if size <= 1 then
		return
	end

	local i = 1
	while true do
		local isOk = false
		local l = i * 2
		local r = (i * 2) + 1
		local parent = self.heap[i]

		-- 注释：优先比较左孩子
		if l <= size then
			local lSon = self.heap[l]
			if self:CompareFunc(lSon, parent) then
				self.heap[i] = self.heap[l]
				self.heap[l] = parent
				i = l
				isOk = true
			end
		end

		if not isOk and r <= size then
			local rSon = self.heap[r]
			if self:CompareFunc(rSon, parent) then
				self.heap[i] = self.heap[r]
				self.heap[r] = parent
				i = r
				isOk = true
			end
		end

		if not isOk or i > size then
			return
		end
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

	local index = #self.heap + 1
	self.heap[index] = {
		unique = u,
		ele = table.copy(ele),
	}
	-- 更新最小堆
	self:Update(index)
end

function MinHeap:GetTop()
	if #self.heap <= 0 then
		return
	end
	return self.heap[1]
end

function MinHeap:Clear()
	self.heap = {}
end

-- 最小堆出栈
function MinHeap:Pop()
	if #self.heap <= 0 then
		return
	end
	local top = self:GetTop()
	local size = #self.heap
	if size == 0 then
		self:Clear()
	elseif size > 1 then
		local size = #self.heap
		self.heap[1] = self.heap[size]
		self.heap[size] = nil
		self:UpdateEx()
	end

	return top
end

function MinHeap:new(unique, sortKeys)
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
		heap = {}
	}
	setmetatable(o, {__index = self})
	return o
end

---------------------

if not table.copy then
	function table.copy(t)
		local result = {}
		for k, v in pairs(t) do
			result[k] = v
		end
		return result
	end
end

local function pprint(obj)
	for k, v in pairs(obj) do
		print(k, v)
	end
end

function main()
	local obj = MinHeap:new("id", {"a", "b", "c"})
	obj:Push({ id = "1", a = 5, b = 2, c = 3, })
	obj:Push({ id = "2", a = 5, b = 2, c = 2, })
	obj:Push({ id = "3", a = 2, b = 2, c = 2, })
	obj:Push({ id = "4", a = 1, b = 2, c = 2, })
	obj:Push({ id = "5", a = 6, b = 2, c = 2, })
	obj:Push({ id = "6", a = 0, b = 2, c = 2, })
	print("len ", #obj.heap)
	print("key ", obj.heap[1].unique)
	-- pprint(obj.heap[1])
end
main()



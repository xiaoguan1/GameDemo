local table = table

function table.empty(t)
	for k, v in pairs(t) do
		return false
	end
	return true
end

function table.size(t)
	local len = 0
	for _, _ in pairs(t) do
		len = len + 1
	end
	return len
end

-- 比较两个table的指针地址是否一样
function table.ptreq(t1, t2)
	return tostring(t1) == tostring(t2)
end

function table.has_value(t, v)
	for _k, _v in pairs(t) do
		if v == _v then
			return _k
		end
	end
end

function table.copy(t)
	local tt = {}
	for k, v in pairs(t) do
		tt[k] = v
	end
	return tt
end

function table.deepcopy(src)
	if type(src) ~= "table" then
		return src
	end
	local function clone_table(t, deep)
		deep = deep or 0
		if deep >= 100 then
			error("deepcopy deep >= 100, fail!")
		end
		local r = {}
		for k, v in pairs(t) do
			local vt = type(v)
			if vt == "userdata" then
				error("not support copy usedata")
			elseif vt == "table" then
				r[k] = clone_table(v, deep + 1)
			else
				r[k] = v
			end
		end
		return r
	end
	return clone_table(src)
end

function table.clear(tbl)
	for k in pairs(tbl) do
		tbl[k] = nil
	end
end

-- 返回一个只读表（若tbl里面还有tbl，想要限制只读，目前只能手打添加。。。。）
function table.onlyread(tbl)
	if type(tbl) ~= "table" then
		_ERROR("table.onlyread arg must table!")
		return
	end

	local rtbl = setmetatable({}, {
		__index = tbl,
		__newindex = function (t, k, v)
			error(string.format("%s only read. key:%s value:%s insert fail!", tbl,k, v))
		end,
		__pairs = function (_rtbl)
			-- 参数 _rtbl 和 rtbl 是一样的，故忽略即可。

			local function filter(t, k)
				local v
				k, v = next(t, k)
				return k, v
			end
			return filter, tbl, nil
		end
	})
	return rtbl
end
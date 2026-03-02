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
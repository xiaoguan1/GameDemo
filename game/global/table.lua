local table = table

function table.empty(t)
	for k, v in pairs(t) do
		return false
	end
	return true
end

function table.size(t)
	local len = 0
	for k, v in pairs(t) do
		len = len + 1
	end
	return len
end


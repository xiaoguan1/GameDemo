local string = string
local table = table

function string.beginswith(str, pattern)
	local sIdx, eIdx = str:find(pattern)
	return sIdx == 1
end

function string.endswith(str, pattern)
	local sLen = str:len()
	local pLen = pattern:len()
	local sIdx = sLen - pLen + 1
	if sIdx <= 0 then
		return
	end
	local _sIdx = str:find(pattern, sIdx)
	return _sIdx == sIdx
end

function string.split(str, sep)
	local res = {}
	for w in str:gmatch(sep) do
		table.insert(res, w)
	end
	return res
end
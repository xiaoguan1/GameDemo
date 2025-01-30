local string = string

function string.endswith(str, pattern)
	local sLen = str:len()
	local pLen = pattern:len()
	local sIdx = sLen - pLen + 1
	if sIdx <= 0 then
		return
	end
	return str:find(pattern, sIdx)
end
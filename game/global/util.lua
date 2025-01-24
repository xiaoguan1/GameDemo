local util = require "util.core"

-- 反向解析util.new_uid函数，获得serverId
local BITCHARS = {
	'0','1','2','3','4','5','6','7','8','9',
	'a','b','c','d','e','f','g','h','i','j',
	'k','l','m','n','o','p','q','r','s','t',
	'u','v',
}
local CHAR_2_NUM = {}
for k, v in ipairs(BITCHARS) do
	CHAR_2_NUM[v] = k - 1
end
function GetServerId_ByUid(uid)
	local serverId = 0
	for i = 7, 12 do
		local no = CHAR_2_NUM[string.sub(uid, i, i)]
		if i == 7 then
			serverId = no & (0x7)
		elseif i == 12 then
			serverId = (serverId << 2) + (no >> 3)
		else
			serverId = (serverId << 5) + no
		end
	end
	return serverId
end
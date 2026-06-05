local skynet = require "skynet"
local skynet_error = skynet.error
local string = string
local table = table
local tinsert = table.insert
local sformat = string.format
local debug = debug
local traceback = debug.traceback

function string.beginswith(str, pattern)
	if type(str) ~= "string" then
		skynet_error(sformat("beginswith str:[%s] error, because str not is string. %s",
			str, traceback()))
		return
	end
	local sIdx, eIdx = str:find(pattern)
	if sIdx == 1 then
		return true, sIdx, eIdx
	end
end

function string.endswith(str, pattern)
	if type(str) ~= "string" then
		skynet_error(sformat("endswith str:[%s] error, because str not is string. %s",
			str, traceback()))
		return
	end
	local sLen = str:len()
	local pLen = pattern:len()
	if pLen > sLen then
		-- 字串的长度大于被匹配的字符串，直接return即可
		return
	end
	local sIdx = sLen - pLen + 1
	local _resIdx = str:find(pattern, sIdx)
	return _resIdx == sIdx
end

function string.split(str, sep)
	if type(str) ~= "string" then
		skynet_error(sformat("split str:[%s] error, because str not is string. %s",
			str, traceback()))
		return
	end
	local res = {}
	for w in str:gmatch(sep) do
		tinsert(res, w)
	end
	return res
end
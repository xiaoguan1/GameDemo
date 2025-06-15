local skynet = require "skynet"
local cell_num = tonumber(skynet.getenv("dbcell_num"))
assert(cell_num and cell_num > 0)

DBCELL_LIST = {}
ACCEPT, RESPONSE = {}, {}, {}

local function _GetCellAddr(source)
	local maxLen = #DBCELL_LIST
	local index = source % #DBCELL_LIST
	if index == 0 then
		index = #DBCELL_LIST
	end
	return DBCELL_LIST[index]
end

function ACCEPT.query(source, command, ...)
	local addr = _GetCellAddr(source)
end

function RESPONSE.query(source, command, ...)
	local addr = _GetCellAddr(source)
end

skynet.start(function ()
	DBCELL_LIST = {}
	for i = 1, cell_num do
		local addr = skynet.newservice("dbcell", i)
		table.insert(DBCELL_LIST, addr)
	end

	skynet.dispatch("lua", function (session, source, command, ...)
		if session == 0 then
			ACCEPT.query(source, command, ...)
		else
			local res = RESPONSE.query(source, command, ...)
			skynet.retpack(res)
		end
	end)
end)














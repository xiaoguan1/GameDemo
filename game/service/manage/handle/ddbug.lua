local skynet = require "skynet"

-- wget -q -O - "http://127.0.0.1:40001/ddbug" 或者 curl "http://127.0.0.1:40001/ddbug"
-- 携带参数：wget -q -O - "http://127.0.0.1:40001/ddbug?key1=value1&key2=value2。。。"

-- local ROLECLASS = Import("game/global/oop/roleclass.lua")
-- Obj = {uid = "1111111111111"}

function Handle_Request(data)
	print(tool.dumptree(data))
	-- print("111---------- ", Obj:GetHaha(), "----------------2222")
end

function __init__()
	-- ROLECLASS.RoleClass:New(Obj)
	-- print("------", Obj.GetHaha, Obj.GetHaha and Obj:GetHaha())
end











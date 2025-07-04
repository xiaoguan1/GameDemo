-- 跳表
local ostime = os.time

SkipList = { __ClassType = "<<skiplist class>>" }

function SkipList:New(len)
	local o = {
		__SuperClass = self,		-- 标记RoleClass为父类
		__IsObject = ostime(),		-- 标记为实例对象
		_Data = {}
	}
	setmetatable(o, {__index = self})
	return o
end







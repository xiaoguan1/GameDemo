--[[
	1. class.lua 不支持热更
	2. 通过NewClass生成的类模板，会支持热更！
]]
local ostime = os.time

M = {}
local AllClasses = {}

function M.NewClass(className)
	assert(className and not AllClasses[className])
	local c = {
		__ClassType = className,
		__CreateClass = ostime(),
	}
	AllClasses[className] = c
	return AllClasses[className]
end

function M.GetAllClasses()
	return AllClasses
end

return M
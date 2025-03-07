-- 洪水填充算法
-- https://blog.csdn.net/qq_46092061/article/details/117092015
-- https://blog.csdn.net/qq_46092061/article/details/117018612

FloodFill = {}
function FloodFill:New()
	local o = {}
	setmetatable(o, {__index = self})
	return o
end





-- 不支持热更

M = {}

function M.NewClass(className)
	assert(className)
	return {__ClassType = className}
end

return M
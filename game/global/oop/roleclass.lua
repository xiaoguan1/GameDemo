-----------------------
--- 玩家类模板
-----------------------

-- 在线玩家对象 ------
ROLE_OBJS = {}

function GetAllRoleObjs()
	return ROLE_OBJS
end

function GetRoleObjByUid(uid)
	return uid and ROLE_OBJS[uid]
end

-- 玩家类 ------
RoleClass = { __ClassType = "<<role class>>" }
function RoleClass:New(o)
	o = o or {}
	if type(o.uid) ~= "string" or ROLE_OBJS[o.uid] then
		_ERROR_F("RoleClass new fail! o:%s", tool.dumptree(o))
		return
	end

	o.__SuperClass = self	-- 标记RoleClass为父类
	o.__ObjectType = true	-- 标记为实例对象
	o.__TempData = {}		-- 重置临时数据

	-- 直接将RoleClass放入o原表的__index里面。
	-- 	若o已设置A函数 且 RoleClass也设置A函数，o:A() 会调用o的而非RoleClass
	setmetatable(o, {__index = self})

	ROLE_OBJS[o.uid] = o
end

function RoleClass:GetUid()
	return self.uid
end

-- 存盘数据
function RoleClass:SetData(fieldName, data)
	self.__Data[fieldName] = data
end
function RoleClass:GetData(fieldName)
	return self.__Data[fieldName]
end

-- 临时数据（上线、下线就没有了）
function RoleClass:SetTempData(fieldName, data)
	self.__TempData[fieldName] = data
end
function RoleClass:GetTempData(fieldName)
	return self.__TempData[fieldName]
end

--autogen-begin
function RoleClass:GetSex()
    return self.__Data.Sex
end
function RoleClass:SetSex(Sex)
    self.__Data.Sex = Sex
end

function RoleClass:GetLike1()
    return self.__TempData.Like1
end
function RoleClass:SetLike1(Like1)
    self.__TempData.Like1 = Like1
end

function RoleClass:GetLike2()
    return self.__TempData.Like2
end
function RoleClass:SetLike2(Like2)
    self.__TempData.Like2 = Like2
end


--autogen-end


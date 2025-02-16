local skynet = require "skynet"
local print = _ERROR or skynet.error

local assert, type, rawget, rawset, tostring = assert, type, rawget, rawset, tostring
local getmetatable, setmetatable = getmetatable, setmetatable
local tpack = table.pack
local tunpack = table.unpack

local pairs = pairs
local ipairs = ipairs
local string = string
local sformat = string.format
local tinsert = table.insert
local tremove = table.remove

local Utils = {}
local AllClass = {}     -- {name = x, ...}
local SuperClass = {}

function Utils.extend( fromTable, toTable )
	if not fromTable or not toTable then
		error( "table can't be nil")
	end
	function _extend( fT, tT )
		for k,v in pairs( fT ) do
			if type( fT[ k ] ) == "table" and type( tT[ k ] ) == "table" then
				tT[ k ] = _extend( fT[ k ], tT[ k ] )
			elseif type( fT[ k ] ) == "table" then
				tT[ k ] = _extend( fT[ k ], {} )
			else
				tT[ k ] = v
			end
		end
		return tT
	end
	return _extend( fromTable, toTable )
end

local ClassBase = {
    __is_class = true,
	__getters = {},
	__setters = {},
}

function SuperCall(sClass)
    return SuperClass[sClass.__name]
end

function ClassBase:__tostring__( id )
    return sformat( "%s (%s)", self.__name, id )
end

local GETSET_CLASSTYPE = {
    NONE = 0,
    SET = 1,
}
function ClassBase:__ctor__(...)
    local o = {
		__is_class = false,
		__getters = {},
		__setters = {},
	}

	local gsClassType = self._GetSetClassType
	if gsClassType == nil then
		local getCnt = table.size(self.__getters)
		local setCnt = table.size(self.__setters)
		if getCnt > 0 and setCnt > 0 then
			error("can not use getset class")
		elseif getCnt > 0 then
			error("can not use get class")
		elseif setCnt > 0 then
			_WARN_F("svrbattle clsss[%s] is set class", self.__name)
			gsClassType = GETSET_CLASSTYPE.SET
		else
			gsClassType = GETSET_CLASSTYPE.NONE
		end
		self._GetSetClassType = gsClassType
	end
	if gsClassType == GETSET_CLASSTYPE.SET then
		local function _newindexFunc(t, k, v)
			local f = t.__setters[k] or self.__setters[k]
			if f then
				f(t, v)
			else
				-- 注意: 直接设置到自己对象就好，不要设置到类哪里
               rawset(t, k, v)
           end
       end
		setmetatable(o, {
			__index = self,
			__newindex = _newindexFunc,
		})
	else
		setmetatable(o, {__index = self})
	end
	--setmetatable(o, {__index = self, __newindex = self})
	if o.__new__ then
		o:__new__(...)
	end
	return o
end

function ClassBase:__ctor__createobj()
	local o = {
		__is_class = false,
		__getters = {},
		__setters = {},
	}

	local gsClassType = self._GetSetClassType
	if gsClassType == nil then
		local getCnt = table.size(self.__getters)
		local setCnt = table.size(self.__setters)
		if getCnt > 0 and setCnt > 0 then
			error("can not use getset class")
		elseif getCnt > 0 then
			error("can not use get class")
		elseif setCnt > 0 then
			_WARN_F("svrbattle class[%s] is set class", self.__name)
			gsClassType = GETSET_CLASSTYPE.SET
		else
			gsClassType = GETSET_CLASSTYPE.NONE
		end
		self._GetSetClassType = gsClassType
	end
	if gsClassType == GETSET_CLASSTYPE.SET then
		local function _newindexFunc(t, k, v)
			local f = t.__setters[k] or self.__setters[k]
			if f then
				f(t, v)
			else
				-- 注意：直接设置到自己对象就好，不要设置到类哪里
				rawset(t, k, v)
			end
		end
		setmetatable(o, {
			__index = self,
			__newindex = _newindexFunc,
		})
	else
		setmetatable(o, {__index = self})
	end
	--setmetatable(o, {__index = self, __newindex = self})
	return 0
end

function ClassBase:constructor(...)
	if self.__new__ then
		self:__new__(...)
	end
	return self
end

function ClassBase:destroy()
end

function ClassBase:__new__( ... )
	return self
end

function newClass(inheritance, params)
	inheritance = inheritance or {}
	params = params or {}
	if not params.name then
		error("newClass requires paramter 'nane'")
	end
	if AllClass[params.name] then
		error("already has class name:" .. params.name)
	end
	if _G[params.name] then
		local msg = sformat("_G[%s] has value", params.name)
		print(msg)
	end

	if inheritance.__is_class == true then
		inheritance = { inheritance }
	elseif ClassBase and #inheritance == 0 then
		-- add default base Class
		tinsert(inheritance, ClassBase)
    else
		if #inheritance > 1 then
			local msg = sformat("newClass:%s parent must <= 1", params.name)
			error(msg)
		end
	end

	-- 把父类的所有东西都deepcopy一遍
	-- local nClass = Utils.extend(inheritance[1], {})
	local o = Utils.extend(inheritance[1], {})
	local function _indexFunc(t, k)
		-- check for key in getters table
		local f = t.__getters[k]
		if f then return f(t) end
	end
	local function _newindexFunc(t, k, v)
		local f = t.__setters[k]
		if f then
			-- found setter, so call it
			f(t, v)
		else
			-- place key/value directly on object
			rawset(t, k, v)
		end
	end
	local function _PairsFunc(t, key)
		while true do
			local nk, nv = next(t, key)
			if not nk then
				return
			end
			if nv ~= t then
				return nk, nv
			else
				key = nk
			end
		end
	end

	--setmetatable 弄 __getters, __setters
	local o_id = tostring(o)
	local mt = {
		__index = _indexFunc,
		__newindex = _newindexFunc,
		__call = function(cls, ...)
			return cls:__ctor__(...)
		end,
		___pairs = function(t)
			return _PairsFunc, t, nil
		end,
	}
	setmetatable(o, mt)

	-- add Class property, access via getters:class()
	o.__class = o
	-- add Class property, access via getters:NAME()
	o.__name = params.name

	o.prototype = o
	AllClass[params.name] = true
	_G[params.name] = o
	SuperClass[params.name] = inheritance[1]

	return o
end

Class = ClassBase

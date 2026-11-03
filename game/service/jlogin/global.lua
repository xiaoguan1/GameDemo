local skynet = require "skynet"
local sformat = string.format
local os_time = os.time

PROXYSVR = Import("game/global/rpc/proxysvr.lua")
GATEWAY_ROUTE = Import("game/global/gateway_route.lua")

-- 网关多实例命名规则（与 startup/main.lua 保持一致：.WGATE、.WGATE2、.WGATE3...）
local function GateName(i)
	if i == 1 then
		return ".WGATE"
	end
	return ".WGATE" .. i
end

-- 最小连接仲裁：选当前节点里连接数最少的网关实例
local function PickGate(cn)
	local gateway_num = tonumber(skynet.getenv("gateway_num")) or 1
	local min_name, min_count
	for i = 1, gateway_num do
		local name = GateName(i)
		local isOk, count = TryCall(PROXYSVR.GetProxy(name, cn, "lua").call, "gate_count")
		if isOk and type(count) == "number" then
			if not min_count or count < min_count then
				min_name, min_count = name, count
			end
		end
	end
	return min_name or GateName(1)
end

-- 玩家登录：wgate 收到未绑定连接的首包后转交到这里
-- id: sockid, uid: 从握手url解析出（可为nil）, url: 握手url, proto_id/payload: 登录首包
function ACCEPT.login(id, uid, url, proto_id, payload)
	-- demo实现：玩家固定落在本节点。真实项目可在此按节点压力选择user节点
	local cn = SELF_CLUSTERNAME

	-- uid 兜底生成（demo：实际项目应做账号校验）
	if not uid or uid == "" then
		uid = sformat("%d_%s", os_time(), tostring(id))
	end

	-- 选网关实例（最小连接）
	local gate_name = PickGate(cn)

	-- 1. 通知玩家逻辑服(agent)记录该玩家所在网关（demo 以 .DISPLAY 充当 agent）
	TryCall(PROXYSVR.GetProxy(".DISPLAY", cn, "lua").send, "bind", uid, gate_name, cn)

	-- 2. 绑定网关连接
	local isOk, isBind = TryCall(PROXYSVR.GetProxy(gate_name, cn, "lua").call, "bind", id, uid, ".DISPLAY", cn)
	if not isOk or not isBind then
		_ERROR_F("login fail, uid:%s bind gate:%s error", uid, gate_name)
		TryCall(PROXYSVR.GetProxy(gate_name, cn, "lua").send, "kick", uid)
		return
	end

	-- 3. 顶号：旧路由存在且不在当前网关，则踢掉旧连接
	local ok2, oldRoute = TryCall(GATEWAY_ROUTE.Get, uid)
	if ok2 and oldRoute then
		if oldRoute.gate_name ~= gate_name or oldRoute.gate_cn ~= cn then
			TryCall(PROXYSVR.GetProxy(oldRoute.gate_name, oldRoute.gate_cn, "lua").send, "kick", uid)
		end
	end

	-- 4. 登记全局路由（中心库）
	TryCall(GATEWAY_ROUTE.Reg, uid, gate_name, cn, ".DISPLAY", cn)

	-- 5. 登录回包（demo：原样回推首包，客户端可据此确认登录成功）
	TryCall(PROXYSVR.GetProxy(gate_name, cn, "lua").send, "push", uid, proto_id, payload)

	_INFO_F("login ok uid:%s gate:%s", uid, gate_name)
end

-- 玩家下线：wgate 连接断开时通知，校验后注销路由
function ACCEPT.logout(uid, gate_name, gate_cn)
	local isOk, route = TryCall(GATEWAY_ROUTE.Get, uid)
	if not isOk or not route then
		-- 没有路由信息，无需处理
		return
	end

	-- 仅当断开的是当前路由所在网关才注销（避免顶号后旧连接断开误删新路由）
	if route.gate_name == gate_name and route.gate_cn == gate_cn then
		TryCall(GATEWAY_ROUTE.UnReg, uid)
		TryCall(PROXYSVR.GetProxy(route.agent_name, route.agent_cn, "lua").send, "unbind", uid)
	end
end
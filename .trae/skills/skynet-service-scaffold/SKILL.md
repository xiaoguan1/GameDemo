---
name: skynet-service-scaffold
description: 按 GameDemo 的 skynet 项目规范生成新玩法服务脚手架，包括服务目录、入口文件、global.lua、业务模块与 namedsvr 注册。当用户要求新建服务、新增玩法服务、创建服务模板或脚手架时使用。不用于修改现有服务逻辑、基础设施服务或协议生成。
---

# skynet 服务脚手架

按本项目规范（见 `.trae/rules/以skynet引擎项目的代码规则.md`）生成新的玩法服务。参考样例：`game/service/agent/`（面向客户端）、`game/service/wgate/`（module 目录分工）、`game/service/display/`（简单服务）。

## 第 1 步：确认输入

向用户确认以下信息（已给出的不要重复问）：

1. **服务名** `svcname`：全小写字母（如 `mail`），named 名为对应大写（`.MAIL`）。
2. **所属节点**：`user`（玩家服）或 `cross`（跨服）。
3. **启动类型**：
   - `normal` —— 随节点常驻启动的一般服务（多数玩法服务选这个）。
   - `adhoc` —— 寄生服务，由中心服数据库 `server_config` 决定在哪个机器节点启动。
   - `unique` 仅限基础设施服务（manage/protosvr 等），**新玩法服务不得加入 unique**。
4. **是否面向客户端协议**：决定是否声明 `CLIENT_ACCEPT`/`CLIENT_RESPONSE` 并注册 `client` 协议。
5. **是否多实例**：默认单实例。多实例需在 config 增加数量 env 参数，并在 `tool/service/startup/main.lua`（或 cross.lua）的 normal 启动循环中增加该服务的数量分支（参考 `gateway_num`/`agent_default_num` 的写法）。

## 第 2 步：创建服务目录

目录结构（每个服务一个子目录，目录名 = 服务名 = 入口文件名）：

```
game/service/<svcname>/
├── <svcname>.lua    # 服务启动入口（skynet.start）
├── global.lua       # 模块装载，只 Import 不写业务逻辑
├── module/          # 业务逻辑模块（ACCEPT/RESPONSE 的具体实现）
└── handle/          # 对外管理指令（可选，含热更指令）
```

### 入口文件模板 `<svcname>.lua`

```lua
local skynet = require "skynet"

ACCEPT = {}
RESPONSE = {}

skynet.start(function ()
	dofile "./game/global/log.lua"

	skynet.dispatch("lua", function (session, _, cmd, ...)
		local f
		if session == 0 then
			f = assert(ACCEPT[cmd], cmd)
			f(...)
		else
			f = assert(RESPONSE[cmd], cmd)
			skynet.retpack(f(...))
		end
	end)

	dofile "game/service/<svcname>/global.lua"
	_INFO_F("<svcname> start ok")
end)
```

要点：以上模板已内建项目规范（session 分发、日志初始化、全局表声明等标准见 rules 第 3/5/8 节），生成时原样复制并替换占位符，不要偏离模板结构。

面向客户端协议的服务（约定见 rules 第 5 节，参照 `agent.lua`），在文件顶部声明协议表并在 `skynet.start` 前注册：

```lua
CLIENT_ACCEPT = {}
CLIENT_RESPONSE = {}

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = skynet.unpack,
	pack = skynet.pack,
	dispatch = function (session, _, command, ...)
		local f
		if session == 0 then
			f = assert(CLIENT_ACCEPT[command], command)
			f(...)
		else
			f = assert(CLIENT_RESPONSE[command], command)
			skynet.retpack(f(...))
		end
	end
}
```

### global.lua 模板

模板（职责标准见 rules 第 3 节）：

```lua
PROXYSVR = Import("game/global/rpc/proxysvr.lua")	-- 需要跨节点调用时
MOD = Import("game/service/<svcname>/module/<modname>.lua")

function ACCEPT.some_cmd(...)
	MOD.SomeFunc(...)
end
```

### module/ 业务模块模板

```lua
local PROXYSVR = Import("game/global/rpc/proxysvr.lua")

-- __ClassType 与生命周期回调的语义、禁用项见 rules 第 4 节
handle = { __ClassType = "<modname>" }

function handle.SomeFunc(...)
end

function __init__()
end

function __update__()
end
```

## 第 3 步：注册 namedsvr.lua

编辑 `game/global/macro/namedsvr.lua`，两处：

1. `ALL_SERVICE_MAP` 增加：

```lua
["<svcname>"] = { named = ".<SVCNAME>" },
```

2. 对应节点的启动顺序表增加服务名：
   - user 节点常驻：`START_USER_SERVICE.normal`
   - user 节点寄生：`START_USER_SERVICE.adhoc`
   - cross 节点寄生：`START_CROSS_SERVICE.adhoc`（cross 的 normal 默认被注释，按需打开）

注意：`genSvrMapRule` 对重复注册、未注册服务会 assert 失败，注册名必须与 `ALL_SERVICE_MAP` 完全一致。

## 不需要改动的部分

- **config 的 luaservice 无需修改**：已包含 `./game/service/?/?.lua`，目录名与入口文件同名即可被扫描到。
- 多实例命名规则：实例 1 为 `.NAME`，实例 N 为 `.NAME` .. N（如 `.WGATE2`）。

## 编码约束检查清单

生成代码后逐项核对：

- [ ] 整体符合 rules 第 4/5/6/7/8 节（Import、命名、日志、TryCall、热更回调禁阻塞、跨节点走 rpc）
- [ ] 服务名全小写、named 名全大写，目录名/入口文件名/namedsvr 注册名一致
- [ ] `ALL_SERVICE_MAP` 与启动顺序表两处都已注册且名称一致（防 genSvrMapRule assert）
- [ ] 占位符 `<svcname>`/`<modname>`/`<SVCNAME>` 已全部替换

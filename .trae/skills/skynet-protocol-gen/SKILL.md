---
name: skynet-protocol-gen
description: 按 GameDemo 的 skynet 项目规范新增或修改游戏协议——编辑 protos 源文件与 rprotomap.lua，运行 gen_proto 生成 pb、协议编号与协议表，并说明热更生效方式。当用户要求新增协议、修改协议、定义消息结构或生成协议表时使用。不用于协议运行时故障排查或手改生成产物。
---

# skynet 协议生成

按本项目规范完成协议的增改。核心链路（详见 `protocol/gen_proto.lua` 头部注释）：

```
手写源：protocol/protos/*.proto（消息结构） + game/global/rprotomap.lua（协议名 -> {desc, request, response}）
    │  运行 sh tool/script/gen_proto.sh（依赖 protoc，Linux 环境）
    ▼
生成物（均禁止手改）：
    protocol/pbs/*.pb        protoc 编译产物（FileDescriptorSet，pbc 运行时加载）
    protocol/save-prot-id    协议名->编号 持久化（旧编号不变，新编号递增）
    protocol/protomap.lua    节点实际加载的协议表（协议名 -> {desc, type, id, request, response}）
```

## 第 1 步：确认改动类型

- 新增协议：改 proto（如需新 message）+ rprotomap.lua 加一条
- 修改已有协议：改 proto 的 message 字段，或改 rprotomap.lua 的 desc/request/response 指向
- 新增 message：只改 proto（供多条协议复用）
- 删除协议：只从 rprotomap.lua 移除条目；编号留在 save-prot-id 占位，防止旧编号被复用

## 第 2 步：编辑 proto 源文件

文件放 `protocol/protos/<名字>.proto`，硬性校验规则（生成器会检查，违反即报错中断）：

1. 必须 `syntax = "proto2";`（项目仅支持 protobuf2，不支持 proto3）
2. `package` 名必须与文件名一致（如 `role.proto` 必须 `package role;`）
3. 同一 package 下 message 不允许重名
4. 消息命名约定：客户端上行 `C2s_xxx`，服务端下行 `S2c_xxx`

```proto
syntax = "proto2";

package role;

message C2s_empty{}

message S2c_role{
    required string uid = 1;
    optional int32 sex = 2;
}
```

兼容性提醒：
- 已有 message **不要新增 required 字段**（旧端/旧数据无法提供会解码失败）；新字段用 `optional` 或新增 message。
- 已有字段**不要改动编号**和类型，只能追加新编号。

## 第 3 步：编辑 rprotomap.lua

在 `game/global/rprotomap.lua` 的 `RPROTOMAP` 表中增改条目。校验规则（生成器检查）：

1. `desc` 必填，长度 1~1023
2. **不能写 `type` 字段**，由脚本按 request/response 自动推导：
   - 有 request + response → `response`（客户端上行、服务端回包）
   - 只有 request → `notify`（客户端上行，无回包）
   - 只有 response → `push`（服务端主动下发）
3. `request`/`response` 必须指向 proto 文件中真实存在的 `package.message`，格式 `包名.Message名`（如 `"role.S2c_role"`），否则报 `message not exist`

```lua
RPROTOMAP = {
	["testresponse"] = { desc = "测试响应类型协议",
		request = "role.C2s_empty",
		response = "role.S2c_role",
	},
	["testpush"] = { desc = "测试推送类型协议",
		response = "role.S2c_role",
	},
}
```

## 第 4 步：运行生成

在 Linux 环境（生成器内部使用 `ls`/`rm -rf`/`touch` 等 shell 命令，Windows 上需在 WSL/编译机执行）：

```bash
sh tool/run.sh    # 菜单选「编译协议」
# 或直接
sh tool/script/gen_proto.sh
```

依赖：
- `protoc` 必须在 PATH 中（生成器用它编译 proto）
- `skynet/3rd/lua/lua` 需已编译（脚本用它执行 gen_proto.lua）

生成器主流程（任一环失败都会报错中断）：
protoc 编译 pb → 校验并加载 save-prot-id → 校验 rprotomap 并分配编号 → 写回编号 → 生成 protomap.lua

## 第 5 步：校验产物

只读检查，不要改：

- `protocol/save-prot-id`：新协议追加在末尾，编号从上一个 +1 递增（编号范围 1~65536，占 2 字节帧头）
- `protocol/protomap.lua`：新增协议按编号顺序出现，type 推导正确
- `protocol/pbs/*.pb`：生成了新的/更新的 pb 文件

## 第 6 步：让运行中的服务生效

- **起服前生成**：无需额外操作，protosvr 起服时注册全部 pb 并加载协议表。
- **热更协议**（服务运行中）：经管理服务对 protosvr 执行 `command.update`（见 `tool/service/basic/protosvr/protosvr.lua`），它会校验 pb、构建新 protobuf 环境并通知各服务重载。
  - 热更限制：**只允许修改或新增 pb 文件，不允许删除已有 pb 文件**（`_Check` 会报 `lost <file>` 失败回滚）。
  - 各业务服务经 `game/global/proto.lua` 各自加载一份协议表，服务热更时重新 dofile protomap 并重建反向索引。

## 检查清单

- [ ] proto 是 proto2，package 名 = 文件名，无重名 message
- [ ] 未给已有 message 加 required 字段，未改已有字段编号
- [ ] rprotomap 未手写 type，request/response 指向的 message 真实存在，desc 已填
- [ ] 在 Linux 环境运行生成，protoc 可用，生成无报错
- [ ] save-prot-id 编号递增正确、protomap.lua 内容符合预期（只读，未手改）
- [ ] 热更时未删除已有 pb 文件

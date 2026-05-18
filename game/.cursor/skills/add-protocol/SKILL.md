---
name: add-protocol
description: >-
  Adds or updates game protocol definitions and handlers in this repository.
  Use when adding tos/toc protocol entries, syncing skynet_lib/Proto.lua with
  client_project/Assets/ScriptLua/Proto.lua (and client/Proto.lua if game/client
  is still used), wiring Unity client (Main.cs/Net.cs/Lua) or client2.lua send
  and toc callbacks, or routing protocol handling to role/public services by
  __mod and __name.
---

# 添加协议（双端一致 + 分发链路）

本 Skill 用于在本仓库新增或修改协议，目标是保证：

- 服务端与客户端协议定义一致
- 客户端发送与回调落地完整
- 服务端按 `__mod + __name` 正确分发到模块
- 公共服务协议可转发并回传网关

## 1. 必须遵守的协议定义规则

协议定义 **必须** 在以下路径 **保持一致**（变量名、字段、`__name`、`__mod`、`Module` 等）：

- `skynet_lib/Proto.lua`（服务端权威定义之一）
- `client_project/Assets/ScriptLua/Proto.lua`（**Unity 正式客户端** Lua 侧）

若仍使用 **`game/client/`** 下联调客户端（如 `client2.lua`），则 **`client/Proto.lua`** 也需与上述两份 **同步**，避免三份定义漂移。

命名格式固定：

- `m_模块名_xxx_tos`（客户端 -> 服务端）
- `m_模块名_xxx_toc`（服务端 -> 客户端）

每条协议必须包含以下字段：

- `__name`：协议名（与变量名一致）
- `__mod`：模块号
- `error`：错误码（默认 0）

并确保 `Module` 表存在并配置模块号映射，例如：

```lua
Module[3] = "mod_scene"
```

## 2. 新增协议的标准流程

### Step A: 在 Proto 多份拷贝间同步新增

1. 在 `skynet_lib/Proto.lua` 新增协议定义  
2. 在 `client_project/Assets/ScriptLua/Proto.lua` **逐字对齐**新增同名、同字段定义  
3. 若仍维护 `game/client` 联调：在 `client/Proto.lua` 同步同样内容  
4. 若是新模块，三处（或两处）均补充 `Module[mod] = "模块名"`（与现有文件风格一致）

检查点：

- `skynet_lib/Proto.lua` 与 `client_project/Assets/ScriptLua/Proto.lua` 中，该协议定义完全一致  
- 若使用 `client/Proto.lua`，与上述两份一致  
- `Proto.mod(__mod)` 能返回正确模块名

### Step B: 客户端发送与回调落地

**正式路径（Unity + XLua）**：在 `client_project` 中由 **`Net.cs` / `NetThread`** 负责收发字节流，**`Main.cs`** 驱动虚拟机；Lua 侧提供与 `client2` 相同约定：

- 发送：构造 `Proto.new("__name", ...)`（或项目统一的封包方式）并入队发送  
- 回调：在 `Proto.mod(__mod)` 对应模块表上实现 **`模块名.协议名(args)`**，函数名与 `__name` 完全一致  

**联调参考（`game/client/client2.lua`）**（若仍使用）：

1. 在 `CMD` 中增加发包入口，构造 `*_tos` 并 `send_proto`  
2. 增加 `模块名.协议名(args)` 回调，用于处理 `*_toc`

示例形态：

```lua
function CMD.scene_xxx(a, b)
    local proto = Proto.new("m_scene_xxx_tos", "a", a, "b", b)
    send_proto(id, proto)
end

function mod_scene.m_scene_xxx_toc(args)
    printf("recv:", vardump(args))
end
```

说明：

- 客户端回调函数名必须与 `__name` 完全一致  
- 回调挂在 `Proto.mod(__mod)` 对应的全局模块表上（如 `mod_scene`）  
- Unity 侧 **`proto_panel`**（见 `client_project` 场景约定）可用于手动发协议调试，实现上应对齐 `Net` 入队接口

### Step C: 角色服务协议处理（玩家进程）

Gate 把协议发给角色服务后，会走 `role.handle_proto` 逻辑：

1. 先确保模块存在（`role` 目录下有对应模块文件）
2. 通过 `__mod` 找模块名，再通过 `__name` 找函数
3. 以解包后的协议表作为参数执行

要求：

- 模块文件内保持 `模块.方法(proto)` 形态
- 方法名与协议 `__name` 一致

### Step D: 公共服务协议处理（如场景服务）

如果协议不应在玩家服务处理，而应在公共服务处理：

1. 在当前分发基础上，增加“指定模块转发到公共服务”的路由
例如skynet.send(scene_handle, "lua", "scene", args)表示让scene_handle服务调用scene[args.__name](args) 
2. 处理后正常return即可，格式return true, key,val,key1,val1,...
3.skynet.dispatch_lua已经支持处理这样的结果，第一个参数表示协议是否处理成功，key，val，key1，val1，...是该协议对应的toc协议的参数的key和值
要求：
--发包路径：客户端->网关->玩家进程->公共服务
- 回包路径明确：公共服务 -> 玩家进程 -> 网关 -> 客户端

## 3. 回调与分发命名约定

- 协议变量名、`__name`、处理函数名三者必须一致
- `tos` 只用于客户端发起；`toc` 只用于服务端回包/推送
- 约定优先使用 `m_模块名_业务动作_tos/toc`

## 4. 提交前检查清单

- [ ] `skynet_lib/Proto.lua` 与 `client_project/Assets/ScriptLua/Proto.lua` 协议定义一致  
- [ ] 若仍使用 `game/client`：`client/Proto.lua` 与上述一致  
- [ ] 协议名符合 `m_模块名_***_tos/toc`  
- [ ] 每条协议都包含 `__name/__mod/error`  
- [ ] `Module` 映射已补充且模块名正确  
- [ ] Unity 客户端已落地发送与 `*_toc` 回调（`Net` / Lua 模块表）；若用 `client2`：已补 `CMD` 与 `模块.协议名` 回调  
- [ ] 服务端存在对应模块与 `协议名` 方法  
- [ ] 涉及公共服务时，转发与回包链路已打通

## 5. 常见错误

- 只改了服务端或只改了 Unity `ScriptLua`，导致 **Proto 不一致**  
- 忘记同步 `client/Proto.lua`（仍在用 `client2` 时）
- `__mod` 正确但 `Module` 未映射，无法找到模块
- 回调挂错命名空间（例如应挂 `mod_scene` 却挂到 `role`）
- 协议逻辑在公共服务，却没有做玩家服务到公共服务的转发

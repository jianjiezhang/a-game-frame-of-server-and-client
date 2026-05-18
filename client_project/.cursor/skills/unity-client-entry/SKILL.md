---
name: unity-client-entry
description: >-
  Hub for AI-assisted work in the Unity client under client_project. Use when
  the user @-mentions client_project/AI-HUB.md, this file, says unity-client-entry,
  or works under client_project (XLua, NetThread, ScriptLua, UI prefabs, scene hierarchy).
---

# Unity 客户端 AI 入口（client_project）

用户在对话里可以：

- **`@client_project/AI-HUB.md`**（最短路径），或  
- **`@client_project/.cursor/skills/unity-client-entry/SKILL.md`**（本文件），或  
- 说明「按 Unity 客户端总入口 / unity-client-entry」  

**先完整阅读本 Skill**，再打开与任务相关的 **规则**；涉及协议或服务端联调时再读 **`game`** 侧 Skill。

## 本目录规则（`.cursor/rules/`）

| 文件 | 何时必须读 |
|------|------------|
| **`unity-client-architecture.mdc`** | 任何 `client_project` 下 C# / Lua / 预制体 / 场景层级 / XLua / 网络线程规划相关改动 |

## 跨仓库（与 game 一起改时）

| 路径 | 何时读 |
|------|--------|
| **`game/.cursor/skills/add-protocol/SKILL.md`** | 新增或修改 tos/toc、**`Proto.lua` 双端同步**、分发与联调 |
| **`game/.cursor/skills/project-entry/SKILL.md`** | 服务端模块、Skynet 服务、Lua 服务逻辑 |

**`Proto.lua` 同步**：`game/skynet_lib/Proto.lua` ↔ `client_project/Assets/ScriptLua/Proto.lua`（必须与 add-protocol Skill 中约定一致）。

## 常用锚点（按需 `Read`）

- `Assets/Scripts/GameStart.cs` — 启动挂载点  
- `Assets/ScriptLua/Main.lua`（启动与每帧 `update`）、`timer.lua`、`minheap.lua`、`Proto.lua`  
- `Assets/Resource/` — 预设  
- 全仓库总路由：`SHARE2-AI-HUB.md`（`share2` 根目录）

## 工作方式

1. 判断改动是否仅客户端、仅服务端、或 **协议/双端**。  
2. 打开上表对应 **全部** 相关 `.mdc` / `SKILL.md`。  
3. 以仓库内 **真实代码与场景** 为准；规则与代码冲突时向用户说明再定。

## XLua 生成（Unity + UI/TMPro）

若修改了 **`Assets/XLua/Examples/ExampleGenConfig.cs`** 中的 **`LuaCallCSharp` / `CSharpCallLua`**：在 Unity 菜单执行 **`XLua` → `Generate Code`**，再编译运行；否则 Lua 中 `CS.TMPro`、`typeof`、`Button.onClick` 等可能不可用。

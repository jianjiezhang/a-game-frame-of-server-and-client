---
name: project-entry
description: >-
  Primary hub for AI-assisted coding in this repository. When the user
  @-mentions AI-HUB.md, `.cursor/skills/project-entry/SKILL.md`, says
  project-entry, or asks to follow the project hub before writing code, read
  this skill fully then open and apply any linked rules or sub-skills that
  match the task before making edits.
---

# 项目 AI 总入口（game 服务端，先读再写代码）

本文件描述 **`game/`** 仓库（Skynet 服务端）内的规则与子 Skill。若工作区是 **`share2`** 根目录且任务涉及 **Unity 客户端**，请先 **`@SHARE2-AI-HUB.md`** 或阅读 **`share2/.cursor/skills/share2-workspace-entry/SKILL.md`** 做分流。

用户在 **`game/`** 对话里可以：

- **`@AI-HUB.md`**（**`game/`** 根目录，最短路径），或  
- **`@.cursor/skills/project-entry/SKILL.md`**（本文件），或  
- 文字说明「按总入口 / hub / project-entry」  

以上任一情况：**先完整阅读本 Skill**，再按任务类型**打开下表对应文件并通读**，最后动手改代码。不要跳过「与当前任务相关」的规则或子 Skill。

## 本仓库里已有的规则（`.cursor/rules/`）

| 文件 | 何时必须读 |
|------|------------|
| **`lua-project-conventions.mdc`** | 任何 **Lua** 业务/服务/模块改动；涉及 **`init`**、**`SERVICE_NAME`**、**`loader`**、**`config` 路径**、模块分层、**`game.lua`** 启动顺序等 |
| **`skynet-vendor-boundary.mdc`** | 可能动到 **`skynet/`** 下树、或纠结「改上游 Lua 还是改自有目录」时 |
| **`database-conventions.mdc`** | 新增/修改数据库表、更新 `db_conf.lua`、生成 SQL 语句 |

## 本仓库里已有的子 Skill（`.cursor/skills/`）

| 目录 / 文件 | 何时必须读 |
|-------------|------------|
| **`new-skynet-service/SKILL.md`** | **新增**或**接线**一个 **`skynet.newservice`** 服务、拆出独立 snlua 服务、对齐 gatemgr / scenemgr / db_service 一类形态时 |
| **`add-protocol/SKILL.md`** | 新增或修改 **tos/toc 协议**、同步 **`skynet_lib/Proto.lua`** 与 **`client_project/Assets/ScriptLua/Proto.lua`**（及按需 **`client/Proto.lua`**）、在 **Unity 客户端（C#/Lua）** 或 **`client2.lua`** 落地发送/回调、或排查 **`__mod + __name`** 分发与公共服务转发链路时 |
| **`add-database-table/SKILL.md`** | **新增**或**修改**数据库表、更新 `db/db_conf.lua`、在 `game/sql/` 下生成 SQL |

以后若在 **`game/.cursor/skills/`** 或 **`game/.cursor/rules/`** 下增加新条目，**应同步在本 Skill 的表格里加一行**，保持总入口可检索。若条目也影响 **`client_project`**，请在 **`share2/.cursor/skills/share2-workspace-entry/SKILL.md`** 的分流表中补充或交叉引用。

## 常用代码锚点（按需 `Read`）

- 根目录 **`config`**：**`luaservice`**、**`lua_path`**、bootstrap 名
- **`game.lua`**、**`game_start.lua`**：进程与服务启动顺序
- **`skynet_lib/loader.lua`**：**`_G`**、**`stdin`**
- **`skynet_service/launcher.lua`**：**`newservice`** 与 **`system` + `init`**

## 工作方式

1. 根据用户诉求归类（新服务 / 改模块 / 只改配置 / 动 skynet 树等）。  
2. 打开上表对应 **全部** 相关 `.mdc` / 子 `SKILL.md`，按其中步骤与约束执行。  
3. 实现时仍以仓库**真实代码**为准；规则与 Skill 与代码冲突时，先向用户说明再决定。

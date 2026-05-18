---
name: new-skynet-service
description: >-
  Adds or wires a new Skynet snlua service in this repo: resolve the script via
  project root `config` luaservice paths, implement SERVICE_NAME-guarded init
  and dispatch, then hook skynet.newservice from game.lua or a parent service.
  Use when the user asks to create a new Skynet service, snlua service,
  newservice, split logic into a service, or mirror patterns like gatemgr,
  scenemgr, db_service.
---

# 在本仓库新增 Skynet 服务

新建服务时对照 **`skynet_service/launcher.lua`** 中 **`launch_service`**：创建成功后会 **`skynet.send(inst, "system", "skynet", "init", ...)`**，服务内由框架走到 **`skynet.init`**，从而调用你在该服务脚本里定义的 **`init`**。

业务逻辑只放在自有目录（**`skynet_service/`**、**`world/`**、**`role/`** 等），**不要**把业务写进 **`skynet/lualib/`** 或 **`skynet/service/`** 等上游自带 Lua 树。

## 1. 定服务名与文件位置

服务名 **`S`** 与 **`skynet.newservice("S")`** 字符串一致；磁盘文件名为 **`S.lua`**，由项目根 **`config`** 的 **`luaservice`** 顺序解析：

- **`skynet_service/S.lua`**（管理类、通用服务常见）
- 或项目根 **`S.lua`**
- 或 **`world/S.lua`** / **`role/S.lua`** / **`world/scene/S.lua`**

按职责选目录，与现有服务风格一致。

## 2. 服务脚本骨架

表名与文件名一致；**所有** **`init`** 以及仅在本服务 VM 内执行的 **`dispatch` / `register`** 等，放在 **`if SERVICE_NAME == "S" then ... end`** 内，避免同一文件被其它服务 **`require`** 时误执行 **`init`**。

```lua
S = {}

-- 可选：对外 API、被其他模块 require 时使用的纯函数

if SERVICE_NAME == "S" then
	function S.init()
		skynet.dispatch("lua", skynet.dispatch_lua)  -- 或自定义协议
		-- skynet.register(".S")
		-- 定时器、状态初始化等
	end
end

return S
```

对照：**`game.lua`**、**`world/gatemgr.lua`**、**`world/scene/scenemgr.lua`**、**`skynet_service/db_service.lua`**。

## 3. 挂到启动链

- 随 **`game`** 常驻：在 **`game.lua`** 的 **`game.start()`** 里 **`skynet.newservice("S")`**，顺序满足依赖（例如必须在 **`config.init()`** 之后的写在它后面）。
- 由父服务动态创建：在父服务 **`init` 或业务代码**里 **`newservice("S")`**，并保存 handle 或具名地址供后续 **`send`/`call`**。

**`game_start.lua`** 一般只拉起 **`game`**，无特殊引导不必改。

## 4. 自检清单

- [ ] **`S.lua`** 落在 **`config` 的 `luaservice`** 可解析路径上  
- [ ] **`return S`**；对外主表名为 **`S`**  
- [ ] **`if SERVICE_NAME == "S" then`** 包住 **`S.init`** 及服务内专属注册逻辑  
- [ ] 常驻服务已在 **`game.lua`** 或其它父逻辑里 **`newservice("S")`**  
- [ ] 若使用 **`skynet.register`**，名称与项目内 **`send`/`call`** 约定一致  
- [ ] 未在 **`skynet/lualib`** / **`skynet/service`** 写业务  

## 5. 服务内复杂状态（可选）

若单文件状态多，推荐：**上值**（**`local __x`**）+ **仅用 `local function` 修改上值** + **`function S.xxx()`** 对外 + 末尾 **`return S`**，与 **`world/scene/scene.lua`** 一类写法同向。

## 6. 路径易混点

- **`skynet_lib/config.lua`**：**sharedata 配置**，不是 **`luaservice`** 路径表。  
- 改 **`luaservice` / `lua_path`** 才影响服务脚本与 **`require`** 查找；改前通读根目录 **`config`**。

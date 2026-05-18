# Game Frame — Skynet + Unity RTS/坦克战斗框架

基于 **Skynet（Lua 服务器）** + **Unity（C# + XLua 客户端）** 构建的多人实时战略游戏框架。支持大规模世界场景（数千对象）、坦克战斗系统以及客户端移动预测。

---

## 项目结构

```
game_frame/
├── game/                          # Skynet 游戏服务器（Lua）
│   ├── config                     # Skynet 启动配置
│   ├── game_start.lua            # 启动入口 — 启动 launcher → game
│   ├── game.lua                  # 主游戏服务 — 启动所有子系统
│   ├── skynet_service/           # 核心系统服务
│   │   ├── launcher.lua          # 服务启动器（fork/管理新服务）
│   │   ├── db_service.lua        # MySQL 连接池服务
│   │   ├── consolemgr.lua        # 调试控制台服务
│   │   └── sharedatad.lua        # 共享数据服务
│   ├── skynet_lib/              # 服务器端库代码
│   │   ├── Proto.lua            # 协议定义（tos/toc，模块分发）
│   │   ├── loader.lua           # 自定义 Lua 加载器，支持配置解析
│   │   ├── stdin.lua            # 游戏时间、表工具、定时器辅助
│   │   ├── skynet.lua           # Skynet 核心 API（send/call/fork/timer 等）
│   │   ├── mysql.lua            # MySQL 封装
│   │   ├── socket.lua           # TCP 套接字 API
│   │   └── config.lua           # 共享数据配置加载器
│   ├── world/                   # 世界级游戏逻辑
│   │   ├── gatemgr.lua          # 连接管理器（认证、网关分发、负载均衡）
│   │   ├── gate.lua             # 每连接网关（套接字、心跳、协议接收）
│   │   ├── adm.lua              # 管理/调试服务
│   │   └── scene/               # 场景子系统（核心游戏世界）
│   │       ├── scenemgr.lua      # 场景管理器 — 创建/销毁场景、追踪角色
│   │       ├── scene.lua        # 世界场景 — 角色/部队/坦克生成、AOI 入离
│   │       ├── scene_battle.lua # 战斗场景 — 双队伍基于血量的自动战斗
│   │       ├── scene_map.lua     # 网格地图 — 分片索引、九宫格邻域
│   │       ├── scene_aoi.lua     # AOI 追踪器 — 每个分片的对象注册表
│   │       ├── scene_objmgr.lua  # 对象管理器 — 生成/移除带类型的对象
│   │       ├── scene_collision.lua # 碰撞网格 — 检测对象距离
│   │       ├── scene_event.lua   # 事件总线（碰撞等）
│   │       ├── scene_role.lua    # 角色实体（无移动、无战斗）
│   │       ├── scene_troop.lua   # 部队实体（行军组件、可战斗）
│   │       ├── scene_tank.lua    # 坦克实体（可战斗）
│   │       ├── scene_monster.lua # 怪物实体
│   │       ├── scene_boss.lua    # Boss 实体
│   │       ├── scene_battle_troop.lua
│   │       ├── scene_battle_tank.lua
│   │       ├── scene_battle_boss.lua
│   │       ├── scene_battle_monster.lua
│   │       └── component/        # 实体组件系统
│   │           ├── base_component.lua
│   │           ├── march_component.lua  # 向目标行军，基于 tick 的移动
│   │           └── battle_component.lua # 自动攻击、血量管理、定时器 tick
│   ├── role/                    # 每个角色的 Lua 服务（每个玩家一个）
│   │   ├── mod_scene.lua       # 场景模块 — 将场景协议路由到场景服务
│   │   └── ...
│   ├── conf/                    # 静态配置
│   │   ├── f_scene.lua         # 场景配置（大小、AOI 网格、行军参数、碰撞半径）
│   │   └── k_scene.lua         # 场景常量（类型 ID、状态、组件类型、事件）
│   ├── db/                      # 数据库层
│   ├── sql/                     # SQL 脚本（game.sql、create_db.sql、clear.sql）
│   ├── client/                   # 独立 C++ 测试客户端
│   └── skynet/                  # Skynet 引擎（C 核心 + Lua 库）
│
├── client_project/               # Unity 游戏客户端
│   ├── Assets/
│   │   ├── Scripts/
│   │   │   ├── Net.cs           # TCP 网络层（带帧的收发、接收队列）
│   │   │   ├── Main.cs          # Unity 入口
│   │   │   └── GameStart.cs
│   │   ├── ScriptLua/           # XLua 脚本（Lua 编写的游戏逻辑）
│   │   │   ├── Main.lua          # 客户端入口、协议分发、命令路由
│   │   │   ├── Proto.lua         # 客户端协议定义（与服务器对应）
│   │   │   ├── watchdog.lua      # 认证看门狗，发送/接收认证协议
│   │   │   ├── role.lua          # 角色逻辑、心跳、回显
│   │   │   ├── mod_scene.lua     # 场景模块（发送/接收场景协议）
│   │   │   ├── scene_panel.lua   # 场景渲染、相机、对象同步、WASD 坦克控制
│   │   │   ├── move_smoother.lua # 插值平滑 + 客户端预测
│   │   │   ├── proto_panel.lua   # 调试输入面板（发送任意命令）
│   │   │   ├── login_panel.lua   # 登录界面
│   │   │   ├── timer.lua         # 客户端定时器
│   │   │   └── minheap.lua       # 最小堆用于定时器调度
│   │   └── Resources/           # Unity 预制体（坦克、部队、怪物、Boss）
│   └── ProjectSettings/
│
└── SHARED2-AI-HUB.md            # AI 工作区入口（请勿编辑）
```

---

## 架构概览

### 服务器 — Skynet 微服务架构

```
客户端（TCP）
    │
    ▼
gatemgr（监听 :8894，认证，网关分发）
    │  负载均衡到 N 个网关
    ▼
gate（每连接，套接字 I/O、协议接收、心跳）
    │  为每个客户端 fork 角色服务
    ▼
role service（每个玩家，拥有玩家状态，路由到场景）
    │
    ├── mod_scene ──────────────► scenemgr（全局，唯一服务）
    │                                  │
    │  ┌─────────────────────────────── ▼
    │  │                          scene（每个世界/战斗一个）
    │  │                            ├── scene_map     （网格 / 九宫格 AOI）
    │  │                            ├── scene_aoi     （每个分片的对象索引）
    │  │                            ├── scene_objmgr  （带类型对象工厂）
    │  │                            ├── scene_collision （距离检测）
    │  │                            ├── scene_event   （事件总线）
    │  │                            └── scene_* （实体：role/troop/tank/monster/boss）
    │  │
    │  ├── scene_battle（自动战斗，双边，定时器结算）
    │  │
    │  └── db_service（MySQL 池 — 角色/账号持久化）
    │
    └── consolemgr（调试控制台）
         sharedatad  （共享配置数据）
```

**启动顺序：** `game_start.lua` → launcher → game service → `scenemgr` → `gatemgr` → `db_service` → `consolemgr` → `sharedatad`

### 协议系统

框架使用简单的**基于文本的 Lua 序列化协议**：

```
格式：  ProtoName|key1;val1;key2;val2;...
        tos = 客户端到服务器请求
        toc = 服务器到客户端响应/通知

按 __mod 索引分发模块：
  1 = watchdog  （连接认证）
  2 = role      （玩家操作）
  3 = mod_scene （场景操作）
```

所有协议定义在双方的 `Proto.lua` 中，添加新消息时必须保持同步。

---

## 核心系统

### 场景系统

- **世界场景**（typeid=1）：2000×2000 地图，50×50 分片网格，2000 个怪物 + 500 个 Boss
- **战斗场景**（typeid=100）：50×50 地图，蓝/红出生点，自动战斗
- **AOI**：九宫格可见区域，对象随分片切换而入离
- 场景配置 `f_scene[typeid]` 控制地图大小、网格大小、行军速度、碰撞半径

### 实体组件系统（ECS）

每个游戏对象（`scene_object`）都有带类型的组件：
- `march_component` — 将对象移向目标位置，在 `march_start()` 时触发
- `battle_component` — 定时器触发对敌队自动攻击，管理血量，广播伤害

### 战斗系统

- 碰撞检测触发战斗创建
- 双队伍自动攻击，基于 tick
- 战斗结算条件：(1) 一方全部死亡，或 (2) 20 秒超时 → 比较总血量
- 胜负结果 + 血量发送给双方玩家

### 客户端移动系统

- **预测**：本地坦克移动立即应用并发送到服务器
- **修正**：比较服务器位置与预测位置；若偏差 > 阈值则修正
- **插值**：所有远程对象以可配置速度进行插值

---

## 快速开始

### 构建服务器

```bash
# Linux/macOS
cd game
make -j$(nproc)

# 运行
./server_start.sh
```

### 构建客户端

在 **Unity 2022.x**（已安装 **XLua** 包）中打开 `client_project/`。项目使用 XLua 在 Unity 中直接运行 Lua 脚本（`Assets/ScriptLua/`）。

### 配置

运行前需更新的关键配置文件：

| 文件 | 修改内容 |
|------|---------|
| `game/config` | `bootstrap`、`start`、`standalone`、服务器端口 |
| `game/world/gatemgr.lua` | `start_socket(port)` — 监听端口、硬编码 IP |
| `client_project/Assets/Scripts/Net.cs` | `_host`、`_port` — 服务器地址 |
| `game/skynet_service/db_service.lua` | MySQL host/port/user/password |
| `game/sql/game.sql` | 数据库结构 |

---

## 关键文件参考

| 分类 | 文件 | 用途 |
|------|------|------|
| 服务器启动 | `game/game_start.lua` | 启动 launcher → game service |
| 服务器主入口 | `game/game.lua` | 注册服务、初始化子系统 |
| 协议定义 | `game/skynet_lib/Proto.lua` | 所有 tos/toc 消息结构 |
| 网关管理 | `game/world/gatemgr.lua` | 认证、网关分发、负载均衡 |
| 每连接网关 | `game/world/gate.lua` | 套接字 I/O 循环、心跳、协议路由 |
| 场景管理器 | `game/world/scene/scenemgr.lua` | 场景生命周期（创建/销毁） |
| 世界场景 | `game/world/scene/scene.lua` | 对象生成、AOI、移动、碰撞 |
| 战斗场景 | `game/world/scene/scene_battle.lua` | 双队伍自动战斗、血量结算 |
| 场景配置 | `game/conf/f_scene.lua` | 每个场景的大小、行军参数、对象数量 |
| 场景常量 | `game/conf/k_scene.lua` | 所有 typeid、状态、组件常量 |
| 行军组件 | `game/world/scene/component/march_component.lua` | 基于 tick 的行军逻辑 |
| 战斗组件 | `game/world/scene/component/battle_component.lua` | 自动攻击、伤害、血量 |
| 客户端网络 | `client_project/Assets/Scripts/Net.cs` | TCP 带帧收发 |
| 客户端入口 | `client_project/Assets/ScriptLua/Main.lua` | 协议分发、命令路由 |
| 场景界面 | `client_project/Assets/ScriptLua/scene_panel.lua` | 3D 场景渲染、相机、控制 |
| 移动系统 | `client_project/Assets/ScriptLua/move_smoother.lua` | 插值 + 客户端预测 |

---

## 数据库结构

```
t_account   — 账号 ID、名称、密码、创建时间、封禁/锁定标志
t_role      — 角色 ID、名称、account_id、server_id、等级、VIP、登录/登出时间
```

---

## 技术栈

- **服务器**：Skynet（C + Lua 5.4），MySQL
- **客户端**：Unity 2022，C# + XLua，TCP 套接字
- **协议**：自定义 Lua 表序列化（name|key;val;...）
- **架构**：微服务（Skynet）、ECS（场景对象 + 组件）

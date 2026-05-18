---
name: add-database-table
description: >-
  新增或修改数据库表的完整流程。当用户要求新增表、添加字段、
  或涉及 db_conf.lua 和 SQL 文件操作时，必须阅读本 Skill 并按步骤执行。
---

# 新增/修改数据库表流程

## 何时使用

用户要求：
- 新增数据库表
- 给现有表添加字段
- 修改 db_conf.lua 配置
- 生成 ALTER TABLE 语句

## 步骤概览

```
┌─────────────────────────────────────────────────────────────┐
│  步骤 1：分析需求                                           │
│  - 确定表名、字段列表、主键                                   │
│  - 确定字段类型（对照类型映射表）                             │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  步骤 2：更新 db_conf.lua                                   │
│  - 在 db/db_conf.lua 添加或修改表配置                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  步骤 3：生成 SQL 语句                                       │
│  - 新增表：写入 game/sql/game.sql                            │
│  - 修改表：写入 game/sql/hotup.sql                           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  步骤 4：告知用户执行                                        │
│  - 告知 SQL 脚本位置和执行命令                                │
│  - 提醒 hotup.sql 需手动清空                                 │
└─────────────────────────────────────────────────────────────┘
```

## 详细步骤

### 步骤 1：分析需求

与用户确认：
- **表名**：格式 `t_xxx`（如 `t_item`、`t_mail`）
- **字段列表**：字段名、类型、默认值、是否主键
- **字段类型**：参考 `database-conventions.mdc` 中的类型映射表

### 步骤 2：更新 db_conf.lua

在 `game/db/db_conf.lua` 中添加配置：

```lua
db_conf.表名 = {
    "实际表名",           -- [1] 数据库表名
    {"主键字段"},         -- [2] 主键列表（供 db.writes/db.reads 使用）
    {
        {"字段名", "类型", 默认值},
        {"字段名", "类型", 默认值},
        -- ...更多字段
    }
}
```

### 步骤 3：生成 SQL

#### 新增表

将 `CREATE TABLE` 语句追加到 `game/sql/game.sql`：

```sql
create table if not exists `t_xxx`
(
    `id` bigint unsigned not null default 0,
    `role_id` bigint unsigned not null default 0,
    `字段名` 类型 not null default 默认值,
    primary key(`id`)
)engine=innodb;
```

#### 修改表

将 `ALTER TABLE` 语句追加到 `game/sql/hotup.sql`：

```sql
alter table `t_xxx` add column `新字段名` 类型 not null default 默认值;
```

### 步骤 4：告知用户

告诉用户：
1. SQL 脚本位置（`game.sql` 或 `hotup.sql`）
2. 执行命令
3. 如果是 `hotup.sql`，提醒执行后手动清空

---

## 完整示例

### 需求：新增物品表 `t_item`

**字段**：
| 字段 | 类型 | 说明 |
|------|------|------|
| id | uint64 | 主键（外部赋值） |
| role_id | uint64 | 角色ID |
| item_id | uint32 | 物品配置ID |
| count | uint32 | 数量 |
| create_time | uint32 | 创建时间 |

### 步骤 1：确认需求（已确认）

### 步骤 2：更新 db_conf.lua

```lua
db_conf.t_item = {
    "t_item",
    {"id"},
    {
        {"id", "uint64", 0},
        {"role_id", "uint64", 0},
        {"item_id", "uint32", 0},
        {"count", "uint32", 0},
        {"create_time", "uint32", 0},
    }
}
```

### 步骤 3：生成 SQL（写入 game.sql）

```sql
create table if not exists `t_item`
(
    `id` bigint unsigned not null default 0,
    `role_id` bigint unsigned not null default 0,
    `item_id` int unsigned not null default 0,
    `count` int unsigned not null default 0,
    `create_time` int unsigned not null default 0,
    primary key(`id`)
)engine=innodb;
```

### 步骤 4：告知用户

```
已完成：
1. db_conf.lua 配置已添加
2. game/sql/game.sql 已更新

请手动执行：
1. 如果是全新数据库：运行 clear.sh 清空，再运行 gen.sh 重建
2. 如果是增量更新：直接执行生成的 SQL

hotup.sql 执行后请手动清空。
```

---

## 注意事项

- **先读规则**：动手前先阅读 `database-conventions.mdc` 规则文件
- **类型映射**：严格按照规则中的类型映射表
- **无自增主键**：主键值由业务层赋值，不使用 AUTO_INCREMENT
- **无外键约束**：仅主键索引
- **hotup.sql 管理**：由用户手动清空

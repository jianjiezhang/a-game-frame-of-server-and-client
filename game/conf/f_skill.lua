
-- 技能配置表（方案A）
-- 技能效果类型说明：
--   damage   : 伤害，attr=使用哪个属性，ratio=属性比例(百分之一)
--   heal     : 治疗，attr=使用哪个属性，ratio=属性比例
--   add_buff : 给目标添加buff，buff_id引用f_buff
--   dot      : 持续伤害，attr=使用哪个属性，ratio=属性比例，interval=间隔(ms)
--
-- target: enemy | self | ally
-- type:   normal | active | passive
-- trigger(被动): on_hit | on_kill | on_start

f_skill = {
    [1] = {
        id = 1,
        name = "普通攻击",
        type = "normal",
        target = "enemy",
        cooldown = 0,
        cast_time = 0,
        priority = 0,
        effects = {
            { type = "damage", attr = "attack", ratio = 100 },
        },
    },
    [2] = {
        id = 2,
        name = "重击",
        type = "active",
        target = "enemy",
        cooldown = 3000,
        cast_time = 500,
        priority = 1,
        effects = {
            { type = "damage", attr = "attack", ratio = 200 },
            { type = "add_buff", buff_id = 1 },
        },
    },
    [3] = {
        id = 3,
        name = "灼烧打击",
        type = "active",
        target = "enemy",
        cooldown = 5000,
        cast_time = 300,
        priority = 1,
        effects = {
            { type = "damage", attr = "attack", ratio = 150 },
            { type = "add_buff", buff_id = 2 },
        },
    },
}

return f_skill

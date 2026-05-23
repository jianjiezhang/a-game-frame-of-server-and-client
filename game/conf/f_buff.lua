
-- Buff 配置表（方案A）
-- tag: 用于互斥判断，同tag的buff高优先级替换低优先级（默认可叠加）
-- layer: 最大叠加层数，nil=不可叠加
-- mods: 属性修改器，apply时合并到attr_mods，remove时剔除
-- dot:   持续伤害配置，存在时on_tick触发dot

f_buff = {
    [1] = {
        id = 1,
        name = "虚弱",
        tag = "debuff",
        duration = 3000,
        layer = 3,
        mods = {
            { attr = "attack", value = -20, type = "flat" },
        },
    },
    [2] = {
        id = 2,
        name = "灼烧",
        tag = "dot",
        duration = 3000,
        layer = 1,
        mods = {
            { attr = "defend", value = -10, type = "flat" },
        },
        dot = {
            attr = "attack",
            ratio = 5,
            interval = 1000,
        },
    },
}

return f_buff

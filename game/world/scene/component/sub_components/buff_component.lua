
-- Buff子组件：管理所有buff/debuff，应用属性修改器
-- 由 battle_component 持有，不直接注册到 scene_object_base.components

buff_component = {}
buff_component.__index = buff_component

function buff_component:new(owner, unit)
    local o = {}
    setmetatable(o, self)
    o.owner = owner     -- battle_component（用于访问enemy_team等）
    o.unit = unit       -- 战斗单位（用于访问attr/base_attr）
    o.active_buffs = {}  -- { buff_id = buff_instance }
    return o
end

-- buff_instance 结构：
-- {
--     cfg = f_buff[buff_id],       -- 原始配置
--     remaining = 3000,            -- 剩余持续时间 ms
--     layer = 1,                   -- 当前叠加层数
--     last_dot_time = 0,          -- 上次触发dot的时间
-- }

function buff_component:add_buff(buff_id)
    local cfg = f_buff[buff_id]
    if not cfg then
        return
    end

    local existing = self.active_buffs[buff_id]
    if existing then
        existing.remaining = cfg.duration
        if cfg.layer then
            existing.layer = math.min(existing.layer + 1, cfg.layer)
        end
    else
        self.active_buffs[buff_id] = {
            cfg = cfg,
            remaining = cfg.duration,
            layer = 1,
            last_dot_time = 0,
        }
    end
    self:apply_mods()
end

function buff_component:remove_buff(buff_id)
    if not self.active_buffs[buff_id] then
        return
    end
    self.active_buffs[buff_id] = nil
    self:apply_mods()
end

function buff_component:has_buff(buff_id)
    return self.active_buffs[buff_id] ~= nil
end

function buff_component:tick()
    local now = stdin.time()
    local tick_interval = 100  -- ms，每tick减少的时间

    for buff_id, buff in pairs(self.active_buffs) do
        -- 处理DOT
        if buff.cfg.dot then
            local dot = buff.cfg.dot
            if now - buff.last_dot_time >= dot.interval then
                buff.last_dot_time = now
                self:trigger_dot(buff)
            end
        end
    end

    -- 先收集要删除的buff_id，避免在迭代中修改表
    local expired = {}
    for buff_id, buff in pairs(self.active_buffs) do
        buff.remaining = buff.remaining - tick_interval
        if buff.remaining <= 0 then
            expired[#expired + 1] = buff_id
        end
    end
    for i = 1, #expired do
        self.active_buffs[expired[i]] = nil
    end
    self:apply_mods()
end

function buff_component:trigger_dot(buff)
    local unit = self.unit
    local dot = buff.cfg.dot
    local value = self:calc_dot_value(dot)
    local new_hp = math.max(0, unit.attr.hp - value)
    unit:update_attr_hp(new_hp)
    unit:update_pobj()
    -- TODO: broadcast dot damage event
end

function buff_component:calc_dot_value(dot)
    local unit = self.unit
    local base = dot.attr and unit.attr[dot.attr] or 0
    return math.floor(base * (dot.ratio or 100) / 100)
end

-- 将所有active_buffs的mods合并，计算最终属性写回unit.attr
function buff_component:apply_mods()
    local unit = self.unit
    -- 重置到基础属性
    if unit.base_attr then
        for k, v in pairs(unit.base_attr) do
            unit.attr[k] = v
        end
    end

    -- 合并所有mods
    for _, buff in pairs(self.active_buffs) do
        local cfg = buff.cfg
        if cfg.mods then
            for i = 1, #cfg.mods do
                local mod = cfg.mods[i]
                local attr_key = mod.attr
                local cur = unit.attr[attr_key] or 0
                if mod.type == "flat" then
                    unit.attr[attr_key] = cur + mod.value * buff.layer
                elseif mod.type == "percent" then
                    unit.attr[attr_key] = math.floor(cur * (1 + mod.value / 100 * buff.layer))
                end
            end
        end
    end
end

return buff_component

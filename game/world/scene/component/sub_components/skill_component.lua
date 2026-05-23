
-- 技能子组件：纯配置驱动
-- 由 battle_component 持有，不直接注册到 scene_object_base.components

skill_component = {}
skill_component.__index = skill_component

function skill_component:new(owner, unit, skill_ids)
    local o = {}
    setmetatable(o, self)
    o.owner = owner    -- battle_component
    o.unit = unit     -- 战斗单位
    o.skills = {}        -- { skill_id = true } 该单位拥有的技能
    o.cooldowns = {}     -- { skill_id = expire_time }
    o.casting = nil      -- 正在引导的技能 { skill_id, cast_end_time, target }

    for _, sid in ipairs(skill_ids or {}) do
        o.skills[sid] = true
    end
    return o
end

function skill_component:tick()
    -- nothing to tick for now (cooldowns managed by parent battle_component)
end

function skill_component:has_skill(skill_id)
    return self.skills[skill_id] == true
end

function skill_component:get_cooldown(skill_id)
    local expire = self.cooldowns[skill_id]
    if not expire then
        return 0
    end
    local now = stdin.time()
    if now >= expire then
        self.cooldowns[skill_id] = nil
        return 0
    end
    return expire - now
end

function skill_component:set_cooldown(skill_id, cooldown_ms)
    local expire = stdin.time() + cooldown_ms
    self.cooldowns[skill_id] = expire
end

function skill_component:can_cast(skill_id, target)
    local def = f_skill[skill_id]
    if not def then
        return false, "skill not found"
    end
    if not self:has_skill(skill_id) then
        return false, "not owned"
    end
    if self:get_cooldown(skill_id) > 0 then
        return false, "cooling down"
    end
    if self.casting then
        return false, "casting"
    end
    if not target or target:is_dead() then
        return false, "invalid target"
    end
    return true
end

function skill_component:start_cast(skill_id, target)
    local def = f_skill[skill_id]
    if not def or def.cast_time <= 0 then
        -- 无引导时间，直接执行
        return self:cast(skill_id, target)
    end
    self.casting = {
        skill_id = skill_id,
        cast_end_time = stdin.time() + def.cast_time,
        target = target,
    }
    return true
end

function skill_component:tick_cast()
    if not self.casting then
        return
    end
    local now = stdin.time()
    if now >= self.casting.cast_end_time then
        local skill_id = self.casting.skill_id
        local target = self.casting.target
        self.casting = nil
        self:cast(skill_id, target)
    end
end

function skill_component:cast(skill_id, target)
    local def = f_skill[skill_id]
    if not def then
        return
    end
    if def.cooldown > 0 then
        self:set_cooldown(skill_id, def.cooldown)
    end
    self:apply_effects(def, target)
end

function skill_component:try_cast(skill_id, target)
    local ok, err = self:can_cast(skill_id, target)
    if not ok then
        return false, err
    end
    return self:start_cast(skill_id, target)
end

function skill_component:apply_effects(def, target)
    for _, eff in ipairs(def.effects or {}) do
        if eff.type == "damage" then
            self:do_damage(target, eff)
        elseif eff.type == "heal" then
            self:do_heal(target, eff)
        elseif eff.type == "add_buff" then
            self:do_add_buff(target, eff)
        end
    end
end

function skill_component:do_damage(target, eff)
    local unit = self.unit
    local value = self:calc_value(eff)
    local damage = math.max(1, value - (target.attr.defend or 0))
    local new_hp = math.max(0, target.attr.hp - damage)
    target:update_attr_hp(new_hp)
    target:update_pobj()
    scene_battle.broadcast_damage(unit.id, target.id, damage, target)
end

function skill_component:do_heal(target, eff)
    local value = self:calc_value(eff)
    local new_hp = math.min(target.attr.max_hp, target.attr.hp + value)
    local healed = new_hp - target.attr.hp
    target:update_attr_hp(new_hp)
    target:update_pobj()
    -- TODO: broadcast heal event
end

function skill_component:do_add_buff(target, eff)
    if not eff.buff_id then
        return
    end
    target:add_buff(eff.buff_id)
end

function skill_component:calc_value(eff)
    local unit = self.unit
    local base = eff.attr and unit.attr[eff.attr] or 0
    return math.floor(base * (eff.ratio or 100) / 100)
end

return skill_component

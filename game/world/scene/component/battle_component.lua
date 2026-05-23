
-- 战斗组件（主组件）：持有 skill/buff 子组件，调度战斗流程
-- 子组件不注册到 scene_object_base，仅由 battle_component 内部使用

battle_component = {}
battle_component.__parent = base_component
battle_component.__index = battle_component

function battle_component:new(owner, ...)
    local tab = self.__parent:new(k_scene.KSCENE_COMPONENT_TYPE_BATTLE, owner, ...)
    setmetatable(tab, self)
    return tab
end

function battle_component:start(obj, enemy_team)
    self.obj = obj
    self.enemy_team = enemy_team
    self.last_attack_time = stdin.time()
    obj:update_state(k_scene.KSCENE_STATE_BATTLE)
    obj:push_component(self)

    -- 创建子组件
    local skill_ids = scene_battle.get_unit_skills(obj.type)
    self.__skill = skill_component:new(self, obj, skill_ids)
    self.__buff = buff_component:new(self, obj)

    self.tick_interval = 100
    local now = stdin.time()
    skynet.timer_push_ends(battle_component.check_tick, now + self.tick_interval / 10, obj.id)
end

function battle_component:tick(obj_id)
    if not self.obj:is_battle() then
        return
    end
    local now = stdin.time()

    -- 调度子组件
    self.__skill:tick()
    self.__skill:tick_cast()
    self.__buff:tick()

    -- 普攻冷却检查
    local elapsed = now - self.last_attack_time
    local interval = 1.0 / (self.obj.attr and self.obj.attr.attack_speed or 1.0) * 1000
    if elapsed * 10 >= interval then
        self:try_attack()
        self.last_attack_time = now
    end

    skynet.timer_push_ends(battle_component.check_tick, now + self.tick_interval / 10, obj_id)
end

function battle_component:try_attack()
    local target = self:pick_enemy()
    if not target then
        return
    end
    -- 随机选择一个可用技能
    local skill_list = {}
    for sid, _ in pairs(self.__skill.skills) do
        if self.__skill:get_cooldown(sid) <= 0 then
            skill_list[#skill_list + 1] = sid
        end
    end
    if #skill_list == 0 then
        return
    end
    local idx = math.random(1, #skill_list)
    local skill_id = skill_list[idx]
    self.__skill:try_cast(skill_id, target)
end

function battle_component:pick_enemy()
    local best = nil
    local best_hp = math.huge
    for _, enemy in pairs(self.enemy_team) do
        if not enemy:is_dead() and enemy.attr.hp > 0 and enemy.attr.hp < best_hp then
            best = enemy
            best_hp = enemy.attr.hp
        end
    end
    return best
end

function battle_component:stop(obj)
    obj:update_state(k_scene.KSCENE_STATE_IDLE)
    skynet.timer_remove(battle_component.check_tick, obj.id)
    obj:pop_component(self)
end

function battle_component.check_tick(obj_id)
    local obj = scene_objmgr.get(obj_id)
    if not obj then
        return
    end
    local comp = obj:get_component(k_scene.KSCENE_COMPONENT_TYPE_BATTLE)
    if comp then
        comp:tick(obj_id)
    end
end

return battle_component

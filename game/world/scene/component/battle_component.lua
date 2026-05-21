
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
    self.tick_interval = 100
    local now = stdin.time()
    skynet.timer_push_ends(battle_component.check_tick, now + self.tick_interval / 10, obj.id)
end

function battle_component:tick(obj_id)
    if not self.obj:is_battle() then
        return
    end
    local now = stdin.time()
    local elapsed = now - self.last_attack_time
    local interval = 1.0 / (self.obj.attr and self.obj.attr.attack_speed or 1.0) * 1000 --每次多少毫秒
    if elapsed * 10 >= interval then
        self:attack()
        self.last_attack_time = now
    end
    skynet.timer_push_ends(battle_component.check_tick, now + self.tick_interval / 10, obj_id)
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

function battle_component:attack()
    local target = self:pick_enemy()
    if not target then
        return
    end
    local damage = self:calc_damage(self.obj.attr, target.attr)
    local new_hp = math.max(0, target.attr.hp - damage)
    target:update_attr_hp(new_hp)
    skynet.warn("battle attack: attacker_id=%d hp=%d target_id=%d hp=%d damage=%d",
        self.obj.id, self.obj.attr.hp, target.id, target.attr.hp, damage)
    target:update_pobj()
    scene_battle.broadcast_damage(self.obj.id, target.id, damage, target)
end

function battle_component:calc_damage(attacker_attr, defender_attr)
    local attack = attacker_attr and attacker_attr.attack or 0
    local defend = defender_attr and defender_attr.defend or 0
    return math.max(1, attack - defend)
end

function battle_component:stop(obj)
    obj:update_state(k_scene.KSCENE_STATE_IDLE)
    skynet.timer_remove(self.check_tick)
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

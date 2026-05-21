


scene_battle_object = setmetatable({}, scene_object_base)
scene_battle_object.__parent = scene_object_base
scene_battle_object.__index = scene_battle_object

function scene_battle_object:new(id, pos)
    local obj = scene_battle_object.__parent:new(id, pos)
    obj.attr = {}
    return setmetatable(obj, self)
end

function scene_battle_object:update_attr(...)
    table.setkv(self.attr, ...)
end

function scene_battle_object:update_attr_hp(val)
    self.attr.hp = val
    if self.attr.hp <= 0 then
        self:update_state(k_scene.KSCENE_STATE_DEAD)
    end
end

function scene_battle_object:notify_broadcast()
    local proto = self:get_proto()
    scene_battle.broadcast(proto)
end
function scene_battle_object:notify_role()
    local proto = self:get_proto()
    scene_battle.notify_role(self.role_id, proto)
end

function scene_battle_object:battle_start(enemy_team)
    local comp = self:get_component(k_scene.KSCENE_COMPONENT_TYPE_BATTLE)
    if not comp then
        return
    end
    comp:start(self, enemy_team)
end

function scene_battle_object:march_start(target_id, pos)
    local comp = self:get_component(k_scene.KSCENE_COMPONENT_TYPE_MARCH)
    if not comp then
        return false
    end
    return comp:start(self, target_id, pos)
end

function scene_battle_object:is_dead()
    return self.state == k_scene.KSCENE_STATE_DEAD
end

function scene_battle_object:is_battle()
    return self.state == k_scene.KSCENE_STATE_BATTLE
end

return scene_battle_object





scene_battle_troop = setmetatable({}, scene_object)
scene_battle_troop.__parent = scene_object
scene_battle_troop.__index = scene_battle_troop

function scene_battle_troop:new(id, pos, extra)
    local obj = scene_battle_troop.__parent:new(id, pos)
    obj.type = k_scene.KSCENE_TYPE_BATTLE_TROOP
    obj.is_collision = false
    obj.can_battle = true
    obj.attr = {
        hp = 1000,
        max_hp = 1000,
        attack = 50,
        defend = 10,
        attack_speed = 1.0,
    }
    if extra then
        table.setkv(obj, table.unpack(extra))
    end
    return setmetatable(obj, self)
end

function scene_battle_troop:gen_pobj()
    self.pobj = {
        id = self.id,
        type = self.type,
        pos = self.pos,
        state = self.state,
        is_dead = self.is_dead or false,
    }
    if self.attr then
        self.pobj.attr = self.attr
    end
    if self.role_id then
        self.pobj.role_id = self.role_id
    end
end

function scene_battle_troop:update_pobj()
    self:gen_pobj()
end

return scene_battle_troop

scene_battle_tank = setmetatable({}, scene_battle_object)
scene_battle_tank.__parent = scene_battle_object
scene_battle_tank.__index = scene_battle_tank

function scene_battle_tank:new(id, pos, extra)
    local obj = scene_battle_tank.__parent:new(id, pos)
    obj.type = k_scene.KSCENE_TYPE_BATTLE_TANK
    obj.is_collision = false
    obj.can_battle = true
    obj.attr = {
        hp = 2000,
        max_hp = 2000,
        attack = 150,
        defend = 50,
        attack_speed = 0.8,
    }
    if extra then
        table.setkv(obj, table.unpack(extra))
    end
    return setmetatable(obj, self)
end

function scene_battle_tank:gen_pobj()
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

return scene_battle_tank

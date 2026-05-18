
scene_battle_boss = setmetatable({}, scene_object)
scene_battle_boss.__parent = scene_object
scene_battle_boss.__index = scene_battle_boss

function scene_battle_boss:new(id, pos, extra)
    local obj = scene_battle_boss.__parent:new(id, pos)
    obj.type = k_scene.KSCENE_TYPE_BATTLE_BOSS
    obj.is_collision = false
    obj.can_battle = true
    obj.attr = {
        hp = 5000,
        max_hp = 5000,
        attack = 100,
        defend = 30,
        attack_speed = 1.5,
    }
    if extra then
        table.setkv(obj, table.unpack(extra))
    end
    return setmetatable(obj, self)
end

function scene_battle_boss:gen_pobj()
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

function scene_battle_boss:update_pobj()
    self:gen_pobj()
end

return scene_battle_boss


scene_battle_monster = setmetatable({}, scene_object)
scene_battle_monster.__parent = scene_object
scene_battle_monster.__index = scene_battle_monster

function scene_battle_monster:new(id, pos, extra)
    local obj = scene_battle_monster.__parent:new(id, pos)
    obj.type = k_scene.KSCENE_TYPE_BATTLE_MONSTER
    obj.is_collision = false
    obj.can_battle = true
    obj.attr = {
        hp = 500,
        max_hp = 500,
        attack = 30,
        defend = 5,
        attack_speed = 1.2,
    }
    if extra then
        table.setkv(obj, table.unpack(extra))
    end
    return setmetatable(obj, self)
end

function scene_battle_monster:gen_pobj()
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
end

function scene_battle_monster:update_pobj()
    self:gen_pobj()
end

return scene_battle_monster

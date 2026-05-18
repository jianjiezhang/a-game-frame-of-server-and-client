scene_monster = setmetatable({}, scene_object)
scene_monster.__index = scene_monster
scene_monster.__parent = scene_object

function scene_monster:new(id, pos, extra)
    local obj = scene_monster.__parent:new(id, pos)
    obj.type = k_scene.KSCENE_TYPE_MONSTER
    obj.is_collision = true
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

function scene_monster:gen_pobj()
    self.pobj = {
        id = self.id,
        type = self.type,
        pos = self.pos,
        state = self.state,
    }
    if self.attr then
        self.pobj.attr = self.attr
    end
end

function scene_monster:update_pobj()
    self:gen_pobj()
end

return scene_monster

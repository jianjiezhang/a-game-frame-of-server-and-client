scene_boss = setmetatable({}, scene_object)
scene_boss.__parent = scene_object
scene_boss.__index = scene_boss

function scene_boss:new(id, pos, extra)
    local obj = scene_boss.__parent:new(id, pos)
    obj.type = k_scene.KSCENE_TYPE_BOSS
    obj.is_collision = true
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

function scene_boss:gen_pobj()
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

function scene_boss:update_pobj()
    self:gen_pobj()
end

return scene_boss

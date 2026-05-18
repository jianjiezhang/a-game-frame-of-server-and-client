scene_tank = setmetatable({}, scene_object)
scene_tank.__parent = scene_object
scene_tank.__index = scene_tank

function scene_tank:new(id, pos, extra)
    local obj = scene_tank.__parent:new(id, pos)
    obj.type = k_scene.KSCENE_TYPE_TANK
    obj.is_collision = true
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
    obj:add_component(march_component)
    return setmetatable(obj, self)
end

function scene_tank:gen_pobj()
    self.pobj = {
        id = self.id,
        type = self.type,
        pos = self.pos,
        state = self.state,
        dir = self.dir,
    }
    if self.attr then
        self.pobj.attr = self.attr
    end
    if self.role_id then
        self.pobj.role_id = self.role_id
    end
end

function scene_tank:update_pobj()
    self:gen_pobj()
end

return scene_tank

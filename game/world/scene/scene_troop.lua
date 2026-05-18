scene_troop = setmetatable({}, scene_object)
scene_troop.__parent = scene_object
scene_troop.__index = scene_troop

function scene_troop:new(id, pos, extra)
    local obj = scene_troop.__parent:new(id, pos)
    obj.type = k_scene.KSCENE_TYPE_TROOP
    obj.is_collision = true
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
    obj:add_component(march_component)
    return setmetatable(obj, self)
end

function scene_troop:gen_pobj()
    local march_comp = self:get_component(k_scene.KSCENE_COMPONENT_TYPE_MARCH)
    self.pobj = {
        id = self.id,
        type = self.type,
        pos = self.pos,
        state = self.state,
    }
    if self.attr then
        self.pobj.attr = self.attr
    end
    if self.role_id then
        self.pobj.role_id = self.role_id
    end
    if march_comp then
        if march_comp.target_id then
            self.pobj.march_target_id = march_comp.target_id
        end
        if march_comp.target_pos then
            self.pobj.march_target_pos = march_comp.target_pos
        end
    end
end

function scene_troop:update_pobj()
    self:gen_pobj()
end

return scene_troop

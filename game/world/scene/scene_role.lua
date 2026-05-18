scene_role = setmetatable({}, scene_object)
scene_role.__parent = scene_object
scene_role.__index = scene_role

function scene_role:new(id, pos, extra)
    local obj = scene_role.__parent:new(id, pos)
    obj.type = k_scene.KSCENE_TYPE_ROLE
    if extra then
        table.setkv(obj, table.unpack(extra))
    end
    return setmetatable(obj, self)
end

function scene_role:gen_pobj()
    self.pobj = {
        id = self.id,
        type = self.type,
        pos = self.pos,
        state = self.state,
    }
    if self.role_id then
        self.pobj.role_id = self.role_id
    end
end

function scene_role:update_pobj()
    self:gen_pobj()
end

return scene_role

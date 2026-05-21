scene_object_base = {}
scene_object_base.__index = scene_object_base

function scene_object_base:new(id, pos)
    local obj = {}
    obj.id = id
    obj.pos = {tx = pos and pos.tx or 0, tz = pos and pos.tz or 0}
    obj.state = k_scene.KSCENE_STATE_IDLE
    obj.components = {}
    obj.cur_components = {}
    return setmetatable(obj, self)
end

function scene_object_base:gen_pobj()
    self.pobj = {
        id = self.id,
        pos = self.pos,
        state = self.state,
    }
end

function scene_object_base:get_proto()
    if not self.pobj then
        return
    end
    return proto.new("m_scene_obj_toc", "obj", self.pobj)
end

function scene_object_base:update_pobj(notify_role, notify_broadcast)
    self:gen_pobj()
    if notify_broadcast then
        self:notify_broadcast()
    end
    if notify_role and self.role_id then
        self:notify_role()
    end
end

function scene_object_base:get_component(comp_type)
    for _, comp in ipairs(self.components) do
        if comp.type == comp_type then
            return comp
        end
    end
end

function scene_object_base:add_component(comp_class, ...)
    local comp = comp_class:new(self, ...)
    table.insert(self.components, comp)
    return comp
end

function scene_object_base:push_component(comp)
    table.insert(self.cur_components, comp)
end

function scene_object_base:pop_component(comp)
    for i = #self.cur_components, 1, -1 do
        if self.cur_components[i] == comp then
            table.remove(self.cur_components, i)
            return
        end
    end
end

function scene_object_base:stop_component(comp_type)
    for i = #self.cur_components, 1, -1 do
        local comp = self.cur_components[i]
        if comp.type == comp_type then
            comp:stop(self)
            return
        end
    end
end

function scene_object_base:stop_all_component()
    for i = #self.cur_components, 1, -1 do
        self.cur_components[i]:stop(self)
    end
end

function scene_object_base:update_state(state, ignore)
    self.state = state
    if not ignore then
        self:update_pobj()
    end
end

return scene_object_base

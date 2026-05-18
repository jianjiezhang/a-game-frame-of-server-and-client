
scene_object = {}
scene_object.__index = scene_object

function scene_object:new(id, pos)
    local obj = {}
    obj.id = id
    obj.pos = {tx = pos and pos.tx or 0, tz = pos and pos.tz or 0}
    obj.state = k_scene.KSCENE_STATE_IDLE
    obj.components = {}
    obj.cur_components = {}
    return setmetatable(obj, self)
end

function scene_object:get_component(comp_type)
    for _, comp in ipairs(self.components) do
        if comp.type == comp_type then
            return comp
        end
    end
end

function scene_object:add_component(comp_class, ...)
    local comp = comp_class:new(self, ...)
    table.insert(self.components, comp)
    return comp
end

function scene_object:push_component(comp)
    table.insert(self.cur_components, comp)
end

function scene_object:pop_component(comp)
    for i = #self.cur_components, 1, -1 do
        if self.cur_components[i] == comp then
            table.remove(self.cur_components, i)
            return
        end
    end
end

function scene_object:stop_component(comp_type)
    for i = #self.cur_components, 1, -1 do
        local comp = self.cur_components[i]
        if comp.type == comp_type then
            comp:stop(self)
            return
        end
    end
end

function scene_object:stop_all_component()
    for i = #self.cur_components, 1, -1 do
        self.cur_components[i]:stop(self)
    end
end

function scene_object:battle_start(enemy_team)
    local comp = self:get_component(k_scene.KSCENE_COMPONENT_TYPE_BATTLE)
    if not comp then
        return
    end
    comp:start(self, enemy_team)
end

function scene_object:march_start(target_id, pos)
    local comp = self:get_component(k_scene.KSCENE_COMPONENT_TYPE_MARCH)
    if not comp then
        return false
    end
    return comp:start(self, target_id, pos)
end

return scene_object

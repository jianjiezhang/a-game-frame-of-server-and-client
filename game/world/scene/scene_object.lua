
scene_object = setmetatable({}, scene_object_base)
scene_object.__parent = scene_object_base
scene_object.__index = scene_object

function scene_object:new(id, pos)
    local obj = scene_battle_object.__parent:new(id, pos)
    obj.attr = {}
    return setmetatable(obj, self)
end

function scene_object:notify_broadcast()
    scene.broadcast_obj(self)
end

function scene_object:notify_role()
    scene.send(self.role_id, self:get_proto())
end

function scene_object:update_attr(...)
    table.setkv(self.attr, ...)
end

function scene_object:destroy()
    scene.destroy_obj(self)
end

return scene_object

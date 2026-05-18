base_component = {}
base_component.__index = base_component

function base_component:new(type, owner, ...)
    local obj = {}
    obj.type = type
    obj.owner = owner
    table.setkv(obj, ...)
    return setmetatable(obj, self)
end



return base_component




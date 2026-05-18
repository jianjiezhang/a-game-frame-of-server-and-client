scene_event = {}

local registry = {}

function scene_event.register(typeid, func)
    if not typeid or not func then
        return
    end
    if not registry[typeid] then
        registry[typeid] = {}
    end
    registry[typeid][func] = true
end

function scene_event.unregister(typeid, func)
    if not typeid or not func then
        return
    end
    if registry[typeid] then
        registry[typeid][func] = nil
    end
end

function scene_event.clear(typeid)
    if not typeid then
        return
    end
    registry[typeid] = nil
end

function scene_event.trigger(typeid, args)
    local list = registry[typeid]
    if not list then
        return
    end
    for func in pairs(list) do
        func(args)
    end
end

return scene_event

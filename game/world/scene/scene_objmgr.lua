
scene_objmgr = {}

local __objects = {}
local __roles = {}
local __next_id = 0
local __classes = {}

local function copy_pos(pos)
    return {tx = pos.tx or 0, tz = pos.tz or 0}
end

function scene_objmgr.init()
    __objects = {}
    __roles = {}
    __next_id = 0
    __classes = {}
    scene_objmgr.register_class(k_scene.KSCENE_TYPE_MONSTER, scene_monster)
    scene_objmgr.register_class(k_scene.KSCENE_TYPE_BOSS, scene_boss)
    scene_objmgr.register_class(k_scene.KSCENE_TYPE_ROLE, scene_role)
    scene_objmgr.register_class(k_scene.KSCENE_TYPE_TROOP, scene_troop)
    scene_objmgr.register_class(k_scene.KSCENE_TYPE_TANK, scene_tank)
end

function scene_objmgr.register_class(obj_type, class)
    __classes[obj_type] = class
end

function scene_objmgr.gen_id()
    __next_id = __next_id + 1
    while __next_id > 0 and __objects[__next_id] do
        __next_id = __next_id + 1
    end
    if __next_id < 0 then
        __next_id = 1
    end
    return __next_id
end

function scene_objmgr.create(obj_type, pos, extra)
    local class = __classes[obj_type]
    if not class then
        return
    end
    local id = scene_objmgr.gen_id()
    local obj = class:new(id, copy_pos(pos or {}), extra)
    obj:gen_pobj()
    scene_objmgr.add(obj)
    if obj.type == k_scene.KSCENE_TYPE_ROLE then
        __roles[obj.role_id] = obj
    end
    return obj
end

function scene_objmgr.add(obj)
    __objects[obj.id] = obj
end

function scene_objmgr.get(obj_id)
    return __objects[obj_id]
end

function scene_objmgr.remove(obj_id)
    local obj = __objects[obj_id]
    if not obj then
        return
    end
    __objects[obj_id] = nil
    if obj.type == k_scene.KSCENE_TYPE_ROLE then
        __roles[obj.role_id] = nil
    end
    return obj
end

function scene_objmgr.get_role_obj(role_id)
    return __roles[role_id]
end

function scene_objmgr.has_role(role_id)
    return __roles[role_id] ~= nil
end

function scene_objmgr.get_role_troops(role_id)
    local role = __roles[role_id]
    return role and role.troops
end

function scene_objmgr.get_first_troop(role_id)
    local troops = scene_objmgr.get_role_troops(role_id)
    return troops and troops[1]
end

function scene_objmgr.get_role_tank(role_id)
    local role = __roles[role_id]
    return role and role.tank
end

return scene_objmgr

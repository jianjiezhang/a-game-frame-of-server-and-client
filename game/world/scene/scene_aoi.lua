scene_aoi = {}

local __types
local __aoi

function scene_aoi.init()
    __types = {
        k_scene.KSCENE_TYPE_ROLE,
        k_scene.KSCENE_TYPE_NPC,
        k_scene.KSCENE_TYPE_MONSTER,
        k_scene.KSCENE_TYPE_BOSS,
        k_scene.KSCENE_TYPE_TROOP,
        k_scene.KSCENE_TYPE_TANK,
    }
    __aoi = {
        slices = {},
        obj_slice = {},
    }
end

function scene_aoi.stop()
    __types = nil
    __aoi = nil
end

function scene_aoi.get()
    return __aoi
end

function scene_aoi.get_slice_tobjs(slice)
    local tobjs = __aoi.slices[slice]
    if tobjs then
        return tobjs
    end
    tobjs = {}
    __aoi.slices[slice] = tobjs
    for _, t in pairs(__types) do
        tobjs[t] = {}
    end
    return tobjs
end

function scene_aoi.enter(obj)
    local slice = scene_map.get_slice(obj.pos)
    local tobjs = scene_aoi.get_slice_tobjs(slice)
    tobjs[obj.type][obj.id] = obj
    __aoi.obj_slice[obj.id] = slice
    return slice
end

function scene_aoi.leave(obj)
    local slice = __aoi.obj_slice[obj.id]
    if not slice then
        return
    end
    local tobjs = scene_aoi.get_slice_tobjs(slice)
    tobjs[obj.type][obj.id] = nil
    __aoi.obj_slice[obj.id] = nil
end

function scene_aoi.move(obj, new_pos)
    local old_slice = __aoi.obj_slice[obj.id]
    obj.pos = {tx = new_pos.tx or 0, tz = new_pos.tz or 0}
    local new_slice = scene_map.get_slice(obj.pos)
    if old_slice == new_slice then
        return old_slice, new_slice
    end
    scene_aoi.leave(obj)
    scene_aoi.enter(obj)
    return old_slice, new_slice
end

function scene_aoi.get_slice_objs(slice)
    local tobjs = scene_aoi.get_slice_tobjs(slice)
    local objs = {}
    for _, tab in pairs(tobjs) do
        table.append(objs, tab)
    end
    return objs
end

function scene_aoi.get_9slices_objs(pos)
    local slices = scene_map.get_9slice(pos)
    local objs = {}
    for _, slice in pairs(slices) do
        table.append(objs, scene_aoi.get_slice_objs(slice))
    end
    return objs
end

function scene_aoi.get_slice_role_ids(slice)
    local tobjs = scene_aoi.get_slice_tobjs(slice)
    local role_ids = {}
    for _, obj in pairs(tobjs[k_scene.KSCENE_TYPE_ROLE]) do
        if obj.role_id then
            role_ids[obj.role_id] = true
        end
    end
    return role_ids
end

function scene_aoi.get_9slice_role_ids(pos)
    local slices = scene_map.get_9slice(pos)
    local role_ids = {}
    for _, slice in pairs(slices) do
        local tab = scene_aoi.get_slice_role_ids(slice)
        for role_id, flag in pairs(tab) do
            role_ids[role_id] = flag
        end
    end
    return role_ids
end

function scene_aoi.get_9slice_role_ids_by_center(slice)
    local map = scene_map.get()
    local max_x = map.max_width_x
    local total = max_x * map.max_width_z
    if slice < 1 or slice > total then
        return {}
    end
    local slice_x = (slice - 1) % max_x
    local slice_z = math.floor((slice - 1) / max_x)
    local center_tx = slice_x * map.width_x + map.width_x * 0.5
    local center_tz = slice_z * map.width_z + map.width_z * 0.5
    return scene_aoi.get_9slice_role_ids({tx = center_tx, tz = center_tz})
end

return scene_aoi

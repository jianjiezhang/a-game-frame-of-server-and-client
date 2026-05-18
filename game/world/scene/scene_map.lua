scene_map = {}

local __map

local __neighbour_offsets = {
    {0, 0}, {-1, 0}, {1, 0},
    {0, 1}, {0, -1}, {1, 1},
    {-1, -1}, {1, -1}, {-1, 1},
}

function scene_map.init(typeid)
    local conf = scene.find_config(typeid)
    if not conf then
        error("scene config missing:" .. tostring(typeid))
    end
    __map = {
        id = conf.id,
        width = conf.width,
        height = conf.height,
        width_x = conf.width_x,
        width_z = conf.width_z,
    }
    __map.max_width_x = math.ceil(__map.width / __map.width_x)
    __map.max_width_z = math.ceil(__map.height / __map.width_z)
    __map.tilemap = {}
end

function scene_map.stop()
    __map = nil
end

function scene_map.get()
    return __map
end

function scene_map.get_slice_x(pos)
    return math.floor((pos.tx or 0) / __map.width_x)
end

function scene_map.get_slice_z(pos)
    return math.floor((pos.tz or 0) / __map.width_z)
end

function scene_map.get_slice(pos)
    local x = scene_map.get_slice_x(pos)
    local z = scene_map.get_slice_z(pos)
    return z * __map.max_width_x + x + 1
end

function scene_map.in_range(x, z)
    return x >= 0 and z >= 0 and x < __map.max_width_x and z < __map.max_width_z
end

function scene_map.get_9slice(pos)
    local slices = {}
    local slice_x = scene_map.get_slice_x(pos)
    local slice_z = scene_map.get_slice_z(pos)
    for _, offset in pairs(__neighbour_offsets) do
        local x = slice_x + offset[1]
        local z = slice_z + offset[2]
        if scene_map.in_range(x, z) then
            table.insert(slices, z * __map.max_width_x + x + 1)
        end
    end
    return slices
end






return scene_map
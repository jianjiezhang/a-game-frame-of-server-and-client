
scene_collision = {}

local __objs = {}
local __check_interval = 100 -- ms

local function get_collision_radius()
    local conf = scene.find_config(scene.get_typeid())
    return (conf and conf.collision_radius) or 2
end

local function check_collision(obj1, obj2, radius)
    local dx = obj1.pos.tx - obj2.pos.tx
    local dz = obj1.pos.tz - obj2.pos.tz
    local dist = math.sqrt(dx * dx + dz * dz)
    if dist <= radius then
        scene_collision.collision(obj1, obj2)
    end
end

function scene_collision.collision(obj1, obj2)
    skynet.warn("collision detected: obj1_id=%d type=%d, obj2_id=%d type=%d",
        obj1.id, obj1.type, obj2.id, obj2.type)
    scene_event.trigger(k_scene.KSCENE_EVENT_COLLISION, {obj1 = obj1, obj2 = obj2})
end

function scene_collision.init()
    local now = stdin.time()
    skynet.timer_push_ends(scene_collision.check_tick, now + __check_interval / 10)
end

function scene_collision.register(obj)
    if not obj.is_collision then
        return
    end
    __objs[obj.id] = obj
end

function scene_collision.unregister(obj)
    __objs[obj.id] = nil
end

function scene_collision.check_tick()
    local radius = get_collision_radius()
    for _, obj in pairs(__objs) do
        local near_objs = scene.get_9slices_objs(obj.pos)
        for _, other in ipairs(near_objs) do
            if other.is_collision and other.id ~= obj.id then
                check_collision(obj, other, radius)
            end
        end
    end
    local now = stdin.time()
    skynet.timer_push_ends(scene_collision.check_tick, now + __check_interval / 10)
end

return scene_collision

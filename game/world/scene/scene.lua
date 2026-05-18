
scene = {}

local __id
local __typeid
local __battles = {}


local function get_troop_born_pos()
    local conf = scene.find_config(__typeid)
    if conf and conf.troop_born then
        return {tx = conf.troop_born.tx, tz = conf.troop_born.tz}
    end
    return {tx = 200, tz = 200}
end

local function try_start_battle(obj1, obj2)
    if not obj1.can_battle or not obj2.can_battle then
        return
    end
    obj1:stop_all_component()
    obj2:stop_all_component()
    obj1.state = k_scene.KSCENE_STATE_BATTLE
    obj2.state = k_scene.KSCENE_STATE_BATTLE
    local battle_data = {
        left = {
            id = obj1.id,
            type = obj1.type,
            role_id = obj1.role_id,
            attr = obj1.attr,
        },
        right = {
            id = obj2.id,
            type = obj2.type,
            role_id = obj2.role_id,
            attr = obj2.attr,
        },
    }
    local cb = {"scene", "settle_battle"}
    local battle = scenemgr.create_battle(skynet.self(), battle_data, cb)
    if not battle then
        skynet.warn("battle: create_battle failed")
        return
    end
    __battles[battle.id] = {
        id = battle.id,
        pid = battle.pid,
        blue_obj = obj1,
        red_obj = obj2,
    }
    skynet.warn("battle started: id=%d pid=%s obj1_id=%d type=%d vs obj2_id=%d type=%d",
        battle.id, tostring(battle.pid), obj1.id, obj1.type, obj2.id, obj2.type)
end

function scene.on_collision(args)
    try_start_battle(args.obj1, args.obj2)
end

function scene.join_battle(role_id, battle_id, unit_data)
    local battle = battle_id and __battles[battle_id]
    if not battle then
        skynet.warn("scene.join_battle: battle not found, battle_id=%s", tostring(battle_id))
        return false, "error", 1
    end
    local side = unit_data.side
    if not side then
        skynet.warn("scene.join_battle: unit_data.side is nil, role_id=%d", role_id)
        return false, "error", 2
    end
    local data = {unit = unit_data}
    skynet.send(battle.pid, "lua", "join", side, data)
    skynet.warn("scene.join_battle: role_id=%d battle_id=%d side=%s", role_id, battle_id, side)
    return true
end

function scene.settle_battle(result)
    local battle_id = result.battle_id
    local battle = battle_id and __battles[battle_id]
    if battle then
        __battles[battle_id] = nil
    end
    skynet.warn("battle end: battle_id=%s result=%s", tostring(battle_id), skynet.vardump(result))
    for _, side in ipairs({result.left, result.right}) do
        for _, unit in ipairs(side) do
            local obj = scene_objmgr.get(unit.id)
            if not obj then
                return
            end
            if unit.is_dead then
                scene_collision.unregister(obj)
                scene_objmgr.remove(obj.id)
                obj:update_pobj()
                scene.broadcast_obj(obj)
            else
                obj.state = k_scene.KSCENE_STATE_IDLE
                obj.attr.hp = unit.hp
                obj:update_pobj()
                scene.broadcast_obj(obj)
            end
        end
    end
end

function scene.find_config(typeid)
    return f_scene[typeid]
end


function scene.send(role_id, proto)
    skynet.send_role_proto(role_id, proto)
end

function scene.broadcast_pos(pos, proto)
    local role_ids = scene_aoi.get_9slice_role_ids(pos)
    for role_id in pairs(role_ids) do
        scene.send(role_id, proto)
    end
end

local function obj_to_pobj(obj)
    return obj and obj.pobj or obj
end

function scene.broadcast_obj(obj)
    local pobj = obj.pobj or obj
    local proto = Proto.new("m_scene_obj_toc", "obj", pobj)
    scene.broadcast_pos(obj.pos, proto)
end

function scene.enter_obj(obj)
    scene_aoi.enter(obj)
    scene.broadcast_obj(obj)
end

function scene.move_obj(obj, new_pos)
    local old_slice, new_slice = scene_aoi.move(obj, new_pos)
    scene.broadcast_obj(obj)
    if old_slice ~= new_slice then
        scene.broadcast_leave_to_diff(obj, old_slice)
    end
end

function scene.broadcast_leave_to_diff(obj, old_slice)
    local old_ids = scene_aoi.get_9slice_role_ids_by_center(old_slice)
    local new_ids = scene_aoi.get_9slice_role_ids_by_center(scene_map.get_slice(obj.pos))
    for role_id in pairs(old_ids) do
        if not new_ids[role_id] then
            local proto = Proto.new("m_scene_slice_leave_toc", "obj", obj_to_pobj(obj))
            scene.send(role_id, proto)
        end
    end
end

function scene.get_9slices_objs(pos)
    return scene_aoi.get_9slices_objs(pos)
end

function scene.get_typeid()
    return __typeid
end

function scene.create_troop(role_id, pos)
    local role = scene_objmgr.get_role_obj(role_id)
    if not role then
        return
    end
    local troop = scene_objmgr.create(k_scene.KSCENE_TYPE_TROOP, pos, {
        "role_id", role_id,
    })
    if not role.troops then
        role.troops = {}
    end
    table.insert(role.troops, troop)
    troop.index = #role.troops
    scene.enter_obj(troop)
    return troop
end

function scene.create_role(role_id, pid, born_pos)
    local role_obj = scene_objmgr.create(k_scene.KSCENE_TYPE_ROLE, born_pos, {
        "role_id", role_id,
        "pid", pid,
    })
    role_obj.role_id = role_id
    role_obj.pid = pid
    role_obj.troops = {}
    scene.enter_obj(role_obj)
    return role_obj
end

function scene.create_tank(role_id, tank_pos)
    local role = scene_objmgr.get_role_obj(role_id)
    if not role then
        return
    end
    local tank = scene_objmgr.create(k_scene.KSCENE_TYPE_TANK, tank_pos, {
        "role_id", role_id,
    })
    role.tank = tank
    scene.enter_obj(tank)
    return tank
end

function scene.enter(role_id, pid)
    local born_pos = get_troop_born_pos()
    local role_obj = scene_objmgr.get_role_obj(role_id)

    if not role_obj then
        role_obj = scene.create_role(role_id, pid, born_pos)
        scene.create_troop(role_id, born_pos)
    else
        scene.enter_obj(role_obj)
    end

    local first_troop = scene_objmgr.get_first_troop(role_id)
    local view_pos = first_troop and first_troop.pos or born_pos
    role_obj.pos = view_pos

    scenemgr.enter(role_id, __id)
    return role_obj, view_pos
end

function scene.leave(role_id)
    local role = scene_objmgr.get_role_obj(role_id)
    if not role then
        return
    end
    scene_aoi.leave(role)
    scenemgr.leave(role_id)
end

function scene.m_scene_enter_tos(args)
    local role_obj, view_pos = scene.enter(args.id, args.pid)
    local pos = view_pos or (role_obj and role_obj.pos) or get_troop_born_pos()
    local objs = scene.get_9slices_objs(pos)
    local filtered = {}
    for _, obj in ipairs(objs) do
        if obj.type ~= k_scene.KSCENE_TYPE_ROLE then
            filtered[#filtered + 1] = obj_to_pobj(obj)
        end
    end
    local troops = role_obj.troops or {}
    local tank = role_obj.tank or {}
    local troops_pobj = {}
    for i, v in ipairs(troops) do
        troops_pobj[i] = obj_to_pobj(v)
    end
    local tank_pobj = obj_to_pobj(tank)
    return true, "pos", pos, "objs", filtered, "troops", troops_pobj, "tank", tank_pobj
end

function scene.m_scene_leave_tos(args)
    scene.leave(args.id)
    return true
end

function scene.m_scene_slices_tos(args)
    local role = scene_objmgr.get_role_obj(args.id)
    if not role then
        return false, "error", 1
    end
    local pos = args.pos
    if pos then
        scene.move_obj(role, pos)
    end
    local objs = scene.get_9slices_objs(role.pos)
    local filtered = {}
    for _, obj in ipairs(objs) do
        if obj.type ~= k_scene.KSCENE_TYPE_ROLE then
            filtered[#filtered + 1] = obj_to_pobj(obj)
        end
    end
    return true, "pos", role.pos, "objs", filtered
end

function scene.m_scene_move_tos(args)
    local role_id = args.id
    local role = scene_objmgr.get_role_obj(role_id)
    if not role then
        return false, "error", 1
    end
    local speed = args.speed or {}
    local new_pos = {
        tx = tonumber(speed.tx) or role.pos.tx,
        tz = tonumber(speed.tz) or role.pos.tz,
    }
    scene.move_obj(role, new_pos)
    return true
end

function scene.m_scene_gen_tank_tos(args)
    local role_id = args.id
    local role = scene_objmgr.get_role_obj(role_id)
    if not role then
        return false, "error", 1
    end
    if role.tank then
        return true, "obj", obj_to_pobj(role.tank)
    end
    local tank_pos
    tank_pos = {tx = role.pos.tx, tz = role.pos.tz}
    local tank = scene.create_tank(role_id, tank_pos)
    return true, "obj", obj_to_pobj(tank)
end

function scene.m_scene_tank_move_tos(args)
    local role_id = args.id
    local role = scene_objmgr.get_role_obj(role_id)
    if not role or not role.tank then
        return false, "error", 3
    end
    local tank = role.tank
    local dirs = args.dir or {}
    local dx, dz = 0, 0
    for _, dir in ipairs(dirs) do
        if dir == "forward" then
            dz = dz + 1
        elseif dir == "backward" then
            dz = dz - 1
        elseif dir == "left" then
            dx = dx - 1
        elseif dir == "right" then
            dx = dx + 1
        end
    end
    if dx ~= 0 or dz ~= 0 then
        local step = 1
        local len = math.sqrt(dx * dx + dz * dz)
        local nx = dx / len
        local nz = dz / len
        tank.dir = {tx = nx, tz = nz}
        local new_pos = {
            tx = tank.pos.tx + nx * step,
            tz = tank.pos.tz + nz * step,
        }
        new_pos.tx = math.max(0, math.min(2000, new_pos.tx))
        new_pos.tz = math.max(0, math.min(2000, new_pos.tz))
        scene.move_obj(tank, new_pos)
        tank:update_pobj()
        local radius = (function()
            local conf = scene.find_config(scene.get_typeid())
            return (conf and conf.collision_radius) or 2
        end)()
        local near_objs = scene.get_9slices_objs(tank.pos)
        for _, other in ipairs(near_objs) do
            if other.is_collision and other.id ~= tank.id then
                local dx2 = tank.pos.tx - other.pos.tx
                local dz2 = tank.pos.tz - other.pos.tz
                local dist = math.sqrt(dx2 * dx2 + dz2 * dz2)
                if dist <= radius then
                    scene.on_collision({obj1 = tank, obj2 = other})
                end
            end
        end
    end
    return true, "obj", obj_to_pobj(tank)
end

function scene.m_scene_march_tos(args)
    local role_id = args.id
    local role = scene_objmgr.get_role_obj(role_id)
    if not role then
        return false, "error", 1
    end
    local troop_index = args.troop_index
    if not troop_index or troop_index < 1 or troop_index > #(role.troops or {}) then
        return false, "error", 2
    end
    local troop = role.troops[troop_index]
    if not troop then
        return false, "error", 2
    end
    local target_id = args.target_id or 0
    if target_id ~= 0 then
        local target_obj = scene_objmgr.get(target_id)
        if not target_obj then
            return false, "error", 3
        end
    end
    if troop.state == k_scene.KSCENE_STATE_MARCH then
        return false, "error", 4
    end
    local pos = args.pos
    skynet.error("scene.m_scene_march_tos troop_index: %d, target_id: %d, pos: %s", troop_index, target_id, skynet.vardump(pos))
    troop:march_start(target_id, pos)
    return true
end

function scene.test_march(role_id, pid, troop_index, target_id, pos)
    -- 校验 troop
    local role = scene_objmgr.get_role_obj(role_id)
    if not role then
        return false, "error", 1, "role not found"
    end
    if not troop_index or troop_index < 1 or troop_index > #(role.troops or {}) then
        return false, "error", 2, "invalid troop_index"
    end
    local troop = role.troops[troop_index]
    if not troop then
        return false, "error", 2, "troop nil"
    end
    if troop.state == k_scene.KSCENE_STATE_MARCH then
        return false, "error", 4, "troop already marching"
    end

    -- 校验目标
    if target_id and target_id ~= 0 then
        local target_obj = scene_objmgr.get(target_id)
        if not target_obj then
            return false, "error", 3, "target not found"
        end
    end

    -- 记录初始状态
    local start_pos = {tx = troop.pos.tx, tz = troop.pos.tz}
    local start_time = stdin.time()

    -- 启动行军
    local ok = troop:march_start(target_id, pos)
    if not ok then
        return false, "error", 6, "march start failed"
    end

    -- 验证启动后状态
    if troop.state ~= k_scene.KSCENE_STATE_MARCH then
        return false, "error", 7, "troop state not marching after start"
    end
    local march_comp = troop:get_component(k_scene.KSCENE_COMPONENT_TYPE_MARCH)
    if march_comp.target_id ~= (target_id or 0) then
        return false, "error", 8, "march_comp.target_id mismatch"
    end
    if not target_id or target_id == 0 then
        if not march_comp.target_pos then
            return false, "error", 9, "march_comp.target_pos should be set"
        end
        if march_comp.target_pos.tx ~= pos.tx or march_comp.target_pos.tz ~= pos.tz then
            return false, "error", 10, "march_comp.target_pos mismatch"
        end
    end

    -- 模拟多次 tick，推进行军
    local conf = scene.find_config(scene.get_typeid())
    local tick_ms = (conf and conf.march and conf.march.tick_ms) or 100
    local stop_dist = (conf and conf.march and conf.march.stop_dist) or 3
    local arrive_dist = (conf and conf.march and conf.march.arrive_dist) or 1
    local speed = (conf and conf.march and conf.march.speed) or 1
    -- stdin.time() 单位为 10ms，tick_interval 需换算为该单位
    local tick_interval = tick_ms / 10
    local max_ticks = 200
    local tick_count = 0

    local target_pos
    if target_id and target_id ~= 0 then
        local target_obj = scene_objmgr.get(target_id)
        target_pos = target_obj and target_obj.pos
    else
        target_pos = pos
    end

    if target_pos then
        local dx = target_pos.tx - start_pos.tx
        local dz = target_pos.tz - start_pos.tz
        local total_dist = math.sqrt(dx * dx + dz * dz)
        local threshold = (target_id and target_id ~= 0) and stop_dist or arrive_dist
        -- step = speed * tick_ms / 1000 = speed * tick_ms / 10 / 100
        local step = speed * tick_ms / 1000
        local expected_ticks = math.ceil((total_dist - threshold) / step)
        max_ticks = math.min(max_ticks, expected_ticks + 10)
    end

    for i = 1, max_ticks do
        local comp = troop:get_component(k_scene.KSCENE_COMPONENT_TYPE_MARCH)
        if comp and troop.state == k_scene.KSCENE_STATE_MARCH then
            comp.last_tick_time = start_time + (i - 1) * tick_interval
            comp:tick(troop.id)
        end

        tick_count = tick_count + 1
        if troop.state ~= k_scene.KSCENE_STATE_MARCH then
            if target_pos then
                local dx = target_pos.tx - troop.pos.tx
                local dz = target_pos.tz - troop.pos.tz
                local arrived_dist = math.sqrt(dx * dx + dz * dz)
                local threshold = (target_id and target_id ~= 0) and stop_dist or arrive_dist
                if arrived_dist > threshold + 0.1 then
                    return false, "error", 11,
                        string.format("troop stopped too far from target: dist=%.2f, threshold=%.2f", arrived_dist, threshold)
                end
            end
            break
        end
    end

    if troop.state == k_scene.KSCENE_STATE_MARCH and tick_count >= max_ticks then
        return false, "error", 12,
            string.format("march did not finish after %d ticks, pos=(%.2f, %.2f)", tick_count, troop.pos.tx, troop.pos.tz)
    end

    -- 验证行军过程中位置在持续变化
    if target_pos then
        local dx = target_pos.tx - start_pos.tx
        local dz = target_pos.tz - start_pos.tz
        local total_dist = math.sqrt(dx * dx + dz * dz)
        local moved_dx = troop.pos.tx - start_pos.tx
        local moved_dz = troop.pos.tz - start_pos.tz
        local moved_dist = math.sqrt(moved_dx * moved_dx + moved_dz * moved_dz)
        if moved_dist < total_dist * 0.9 then
            return false, "error", 13,
                string.format("troop did not move enough: total=%.2f, moved=%.2f", total_dist, moved_dist)
        end
    end

    -- 验证行军停止后状态已重置
    if troop.state ~= k_scene.KSCENE_STATE_IDLE then
        return false, "error", 14, "troop state not IDLE after march stopped"
    end
    if march_comp.target_id ~= nil or march_comp.target_pos ~= nil then
        return false, "error", 15, "march_comp target not cleared after march stopped"
    end

    return true, "ok", 0, string.format(
        "march test passed: start=(%.2f,%.2f) end=(%.2f,%.2f) ticks=%d",
        start_pos.tx, start_pos.tz, troop.pos.tx, troop.pos.tz, tick_count
    )
end

if SERVICE_NAME == "scene" then

local function init_monsters()
    local conf = scene.find_config(__typeid)
    if not conf then
        return
    end
    local count = conf.monster_count or 0
    local boss_count = conf.boss_count or 0
    local map_width = conf.width or 1000
    local map_height = conf.height or 1000
    for i = 1, count do
        local pos = {
            tx = math.random(0, map_width),
            tz = math.random(0, map_height),
        }
        local obj = scene_objmgr.create(k_scene.KSCENE_TYPE_MONSTER, pos)
        scene.enter_obj(obj)
    end
    for i = 1, boss_count do
        local pos = {
            tx = math.random(0, map_width),
            tz = math.random(0, map_height),
        }
        local obj = scene_objmgr.create(k_scene.KSCENE_TYPE_BOSS, pos)
        scene.enter_obj(obj)
    end
end

function scene.init(id, typeid, is_system)
    skynet.dispatch("lua", skynet.dispatch_lua)
    skynet.timer_init()
    local procname = is_system and (".scene_" .. tostring(id)) or (".scene_" .. tostring(typeid) .. "_" .. tostring(id))
    skynet.register(procname)
    __id, __typeid = id, typeid
    scene_map.init(__typeid)
    scene_objmgr.init()
    scene_aoi.init()
    scene_collision.init()
    scene_event.register(k_scene.KSCENE_EVENT_COLLISION, scene.on_collision)
    init_monsters()
end

function scene.stop()
    scenemgr.stop_scene(__id)
    scene_map.stop()
    scene_aoi.stop()
    scene_event.clear(k_scene.KSCENE_EVENT_COLLISION)
    __battles = {}
    __id = nil
    __typeid = nil
end

function scene.GETLOG()
    if __id and __typeid then
        return "[scene " .. __id .. " " .. __typeid .. "]:"
    end
    return "[scene]:"
end


end




return scene



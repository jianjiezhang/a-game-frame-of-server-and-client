
scene_battle = {}

local __scene_pid
local __battle_id
local __battle_typeid
local __battle_data
local __left_team = {}
local __right_team = {}
local __start_time
local __result_reported = false
local __player_role_ids = {}  -- 所有参战玩家 role_id 集合，key=role_id

-- 兵种类型 → 拥有的技能id列表
local __hash_skills


local function register_player_role_id(role_id)
    if role_id and role_id ~= 0 then
        __player_role_ids[role_id] = true
    end
end

local function register_obj_role_id(obj)
    register_player_role_id(obj.role_id)
end

local function broadcast(proto)
    for role_id in pairs(__player_role_ids) do
        skynet.send_role_proto(role_id, proto)
    end
end

local function get_battle_type(real_type)
    if real_type == k_scene.KSCENE_TYPE_TANK then
        return k_scene.KSCENE_TYPE_BATTLE_TANK
    elseif real_type == k_scene.KSCENE_TYPE_MONSTER then
        return k_scene.KSCENE_TYPE_BATTLE_MONSTER
    elseif real_type == k_scene.KSCENE_TYPE_BOSS then
        return k_scene.KSCENE_TYPE_BATTLE_BOSS
    elseif real_type == k_scene.KSCENE_TYPE_TROOP then
        return k_scene.KSCENE_TYPE_BATTLE_TROOP
    end
    return real_type
end

local function is_side_dead(team)
    for _, obj in pairs(team) do
        if not obj:is_dead() and obj.attr.hp > 0 then
            return false
        end
    end
    return true
end

local function pick_winner_by_hp()
    local function total_hp(team)
        local sum = 0
        for _, obj in pairs(team) do
            sum = sum + (obj.attr.hp or 0)
        end
        return sum
    end
    if total_hp(__left_team) >= total_hp(__right_team) then
        return "left"
    else
        return "right"
    end
end

local function stop_check_timer()
    skynet.timer_remove(scene_battle.check_result)
end

local function on_battle_end(winner_side)
    if __result_reported then
        return
    end
    __result_reported = true
    stop_check_timer()

    local left_hp = 0
    local right_hp = 0
    for _, obj in ipairs(__left_team) do
        left_hp = left_hp + obj.attr.hp
    end
    for _, obj in ipairs(__right_team) do
        right_hp = right_hp + obj.attr.hp
    end

    scene_battle.broadcast_battle_end(winner_side, left_hp, right_hp)
    local winner_str = winner_side or "none"
    local result = {
        battle_id = __battle_id,
        winner = winner_side,
        left = {},
        right = {},
    }
    for _, obj in pairs(__left_team) do
        table.insert(result.left, {id = obj.src_id, type = obj.type, hp = obj.attr.hp, max_hp = obj.attr.max_hp, is_dead = obj:is_dead()})
    end
    for _, obj in pairs(__right_team) do
        table.insert(result.right, {id = obj.src_id, type = obj.type, hp = obj.attr.hp, max_hp = obj.attr.max_hp, is_dead = obj:is_dead()})
    end
    skynet.warn("===== BATTLE RESULT =====\n  battle_id=%d winner=%s\n  left_total_hp=%d  right_total_hp=%d",__battle_id, winner_str, left_hp, right_hp)
    skynet.warn("scene_battle.on_battle_end: result=%s", skynet.vardump(result))
    if __callback then
        skynet.send(__scene_pid, "lua", __callback[1], __callback[2], result)
    end
    scene_battle.finish()
end


function scene_battle.get_unit_skills(unit_type)
    return __hash_skills[unit_type] or { 1 }  -- 默认仅有普攻
end
function scene_battle.broadcast_damage(attacker_id, target_id, damage, target)
    local proto = Proto.new("m_scene_battle_damage_toc",
        "attacker_id", attacker_id,
        "target_id", target_id,
        "damage", damage,
        "target_hp", target.attr.hp,
        "target_max_hp", target.attr.max_hp,
        "target_dead", target:is_dead() or false
    )
    broadcast(proto)
end

function scene_battle.broadcast_battle_end(winner_side, left_hp, right_hp)
    local left_objs = {}
    for _, obj in pairs(__left_team) do
        table.insert(left_objs, {id = obj.id, type = obj.type, hp = obj.attr.hp, max_hp = obj.attr.max_hp, is_dead = obj:is_dead()})
    end
    local right_objs = {}
    for _, obj in pairs(__right_team) do
        table.insert(right_objs, {id = obj.id, type = obj.type, hp = obj.attr.hp, max_hp = obj.attr.max_hp, is_dead = obj:is_dead()})
    end
    local proto = Proto.new("m_scene_battle_end_toc",
        "battle_id", __battle_id,
        "winner", winner_side or "",
        "left_hp", left_hp,
        "right_hp", right_hp,
        "left_objs", left_objs,
        "right_objs", right_objs
    )
    broadcast(proto)
end

function scene_battle.check_result()
    if __result_reported then
        return
    end
    local now = stdin.time()
    local elapsed = now - __start_time

    if elapsed >= 20*100 then
        local winner = pick_winner_by_hp()
        on_battle_end(winner)
        return
    end
    if is_side_dead(__left_team) then
        on_battle_end("right")
        return
    end
    if is_side_dead(__right_team) then
        on_battle_end("left")
        return
    end

    skynet.timer_push_ends(scene_battle.check_result, stdin.time()+100)
end

function scene_battle.finish()
    skynet.exit_service()
end

function scene_battle.stop()
    on_battle_end(nil)
    scenemgr.stop_scene(__battle_id)
end

function scene_battle.join(side, battle_data)
    if side ~= "left" and side ~= "right" then
        skynet.error("scene_battle.join: invalid side " .. tostring(side))
        return
    end
    if __result_reported then
        skynet.error("scene_battle.join: battle already ended, battle_id=" .. __battle_id)
        return
    end

    local team = (side == "left") and __left_team or __right_team
    local enemy_team = (side == "left") and __right_team or __left_team

    local unit_data = battle_data.unit
    local unit_type = get_battle_type(unit_data.type)
    local unit_extra = {role_id = unit_data.role_id, attr = unit_data.attr}

    local conf = f_scene[k_scene.KSCENE_BATTLE_MAP_TYPEID]
    local blue_pos = (conf and conf.blue_born) or {tx = 10, tz = 25}
    local red_pos  = (conf and conf.red_born)  or {tx = 40, tz = 25}
    local pos = (side == "left") and blue_pos or red_pos

    local obj = scene_objmgr.create(unit_type, pos, unit_extra)
    if not obj then
        skynet.error("scene_battle.join: failed to create unit, side=" .. side)
        return
    end
    obj:add_component(battle_component)
    obj:battle_start(enemy_team)
    register_obj_role_id(obj)
    table.insert(team, obj)

    skynet.error(string.format(
        "scene_battle.join: battle_id=%d side=%s new_unit_id=%d hp=%d team_size=%d",
        __battle_id, side, obj.id, obj.attr.hp, #team
    ))
end

function scene_battle.broadcast(proto)
    broadcast(proto)
end

function scene_battle.notify_role(role_id, proto)
    skynet.send_role_proto(role_id, proto)
end

if SERVICE_NAME == "scene_battle" then

function scene_battle.init(id, typeid, is_system, scene_pid, battle_data, callback)
    skynet.dispatch("lua", skynet.dispatch_lua)
    skynet.timer_init()
    __battle_id = id
    __battle_typeid = typeid
    __scene_pid = scene_pid
    __battle_data = battle_data
    __callback = callback
    __result_reported = false
    __start_time = stdin.time()
    __hash_skills = {     
        [k_scene.KSCENE_TYPE_BATTLE_TANK] = { 1, 2, 3 },
        [k_scene.KSCENE_TYPE_BATTLE_MONSTER] = { 1, 2, 3 },
        [k_scene.KSCENE_TYPE_BATTLE_BOSS] = { 1, 2, 3 },
        [k_scene.KSCENE_TYPE_BATTLE_TROOP] = { 1, 2, 3 }}

    scene_objmgr.init()
    scene_objmgr.register_class(k_scene.KSCENE_TYPE_BATTLE_TANK,   scene_battle_tank)
    scene_objmgr.register_class(k_scene.KSCENE_TYPE_BATTLE_MONSTER, scene_battle_monster)
    scene_objmgr.register_class(k_scene.KSCENE_TYPE_BATTLE_BOSS,   scene_battle_boss)
    scene_objmgr.register_class(k_scene.KSCENE_TYPE_BATTLE_TROOP, scene_battle_troop)

    local conf = f_scene[k_scene.KSCENE_BATTLE_MAP_TYPEID]
    local blue_pos = (conf and conf.blue_born) or {tx = 10, tz = 25}
    local red_pos  = (conf and conf.red_born)  or {tx = 40, tz = 25}

    local left_data  = battle_data.left
    local right_data = battle_data.right

    register_player_role_id(left_data.role_id)
    register_player_role_id(right_data.role_id)

    local function build_team(side_data, pos, side_name)
        local team = {}
        local unit_type = get_battle_type(side_data.type)
        local unit_extra = {"role_id", side_data.role_id, "attr", side_data.attr, "src_id", side_data.id}
        local obj = scene_objmgr.create(unit_type, pos, unit_extra)
        if not obj then
            skynet.error("scene_battle init: failed to create unit for " .. side_name)
            return nil
        end
        register_obj_role_id(obj)
        obj:add_component(battle_component)
        table.insert(team, obj)
        return team
    end
    skynet.warn("scene_battle.init: left_data=%s right_data=%s", skynet.vardump(left_data), skynet.vardump(right_data))
    local left_team  = build_team(left_data,  blue_pos, "left")
    local right_team = build_team(right_data, red_pos, "right")

    if not left_team or not right_team then
        skynet.error("scene_battle init: failed to create battle objects")
        return
    end

    __left_team  = left_team
    __right_team = right_team

    local left_obj  = __left_team[1]
    local right_obj = __right_team[1]
    for _, obj in ipairs(__left_team) do
        obj:battle_start(__right_team)
    end
    for _, obj in ipairs(__right_team) do
        obj:battle_start(__left_team)
    end

    skynet.error(string.format(
        "scene_battle init: battle_id=%d left_id=%d type=%d hp=%d vs right_id=%d type=%d hp=%d",
        __battle_id,
        left_obj.id, left_obj.type, left_obj.attr.hp,
        right_obj.id, right_obj.type, right_obj.attr.hp
    ))

    scene_battle.check_result()
end

function scene_battle.GETLOG()
    return "[scene_battle]:"
end

end

return scene_battle

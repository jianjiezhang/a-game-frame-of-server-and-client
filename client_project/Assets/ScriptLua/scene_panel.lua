--- scene_panel：大世界场景面板，处理进入场景、对象创建、视野移动
scene_panel = {}

local CS = CS
local UnityEngine = CS.UnityEngine
local Debug = UnityEngine.Debug
local Resources = UnityEngine.Resources
local GameObject = UnityEngine.GameObject
local Vector3 = UnityEngine.Vector3
local Camera = UnityEngine.Camera
local Quaternion = UnityEngine.Quaternion
local Input = UnityEngine.Input
local Screen = UnityEngine.Screen

local scene_root
local scene_camera

local __go_map = {}

local __scene_pos = {tx = 0, tz = 0}
local __obj_data = {}       -- id -> obj 数据（供业务层查询）
local __last_slice_x = nil
local __last_slice_z = nil
local __in_scene = false
-- 战斗状态转圈圈记录：obj_id -> { origin_tx, origin_tz, start_time }
local __battle_circle = {}

local view_target_pos
local CLICK_MOVE_THRESHOLD = 5
local is_dragging = false
local mouse_down_pos_x = 0
local mouse_down_pos_y = 0

-- tank 跟随模式：nil / "tank" / "self"
local tank_follow_mode
local local_tank_pos
local local_tank_id   -- 本地 tank 的对象 id，用于 prediction 系统

-- 键盘 tank 移动
local TANK_MOVE_INTERVAL = 0.05
local TANK_MOVE_SPEED = 2
local TANK_STEP = 1       -- 与服务端保持一致，每步移动量
local tank_move_dir = nil  -- "forward"/"backward"/"left"/"right"
local tank_move_timer = 0

local DRAG_SPEED_X = 2
local DRAG_SPEED_Y = 2

local CAMERA_OFFSET_Y = 20
local CAMERA_OFFSET_X = 0
local CAMERA_OFFSET_Z = -20

local k_scene_type_role = 1
local k_scene_type_npc = 2
local k_scene_type_monster = 3
local k_scene_type_boss = 4
local k_scene_type_troop = 5
local k_scene_type_tank = 6

local k_scene_state_idle = 0
local k_scene_state_battle = 2

-- 战斗状态转圈圈配置
local BATTLE_CIRCLE_RADIUS = 10
local BATTLE_CIRCLE_SPEED = 90   -- 角度/秒，90°/s 约 4 秒转一圈



local function printf(fmt, ...)
    print(string.format("[scene_panel] " .. tostring(fmt), ...))
end

local function world_to_screen_pos(tx, tz)
    return Vector3(tx, 0, tz)
end

local function create_object_by_type(obj_type)
    local prefab_name
    if obj_type == k_scene_type_monster then
        prefab_name = "common_monster"
    elseif obj_type == k_scene_type_boss then
        prefab_name = "Boss"
    elseif obj_type == k_scene_type_troop then
        prefab_name = "troop"
    elseif obj_type == k_scene_type_tank then
        prefab_name = "tankFbx"
    end

    local prefab = Resources.Load(prefab_name)

    if prefab then
        local go = GameObject.Instantiate(prefab, scene_root)
        go:SetActive(true)
        return go
    end
end

-- 将 __obj_data 与 __go_map 对齐：新增 / 销毁 / 更新
local function sync_objects()
    local existing_ids = {}
    for id, _ in pairs(__go_map) do
        existing_ids[id] = true
    end

    for id, obj in pairs(__obj_data) do
        existing_ids[id] = nil

        local go = __go_map[id]
        if not go then
            go = create_object_by_type(obj.type)
            __go_map[id] = go
        end

        if go and obj.pos then
            if id ~= local_tank_id then
                move_smoother.SetTarget(id, obj.pos)
            end
        end
    end

    for id, _ in pairs(existing_ids) do
        local go = __go_map[id]
        if go then
            GameObject.Destroy(go)
            __go_map[id] = nil
            move_smoother.Remove(id)
        end
    end
end

local function update_camera_position()
    if not scene_camera then
        return
    end
    local target
    if tank_follow_mode == "tank" and local_tank_id then
        local pred = move_smoother.GetPredictPos()
        if pred then
            target = world_to_screen_pos(pred.tx, pred.tz)
        end
    elseif tank_follow_mode == "tank" and local_tank_pos then
        target = world_to_screen_pos(local_tank_pos.tx, local_tank_pos.tz)
    elseif view_target_pos then
        target = world_to_screen_pos(view_target_pos.tx, view_target_pos.tz)
    end
    if not target then
        return
    end
    local camera_pos = Vector3(
        target.x + CAMERA_OFFSET_X,
        target.y + CAMERA_OFFSET_Y,
        target.z + CAMERA_OFFSET_Z
    )

    scene_camera.transform.position = camera_pos
    scene_camera.transform:LookAt(target)
end

local function try_click_ground(screen_x, screen_y)
    if not scene_camera then
        return
    end

    local ray = scene_camera:ScreenPointToRay(Vector3(screen_x, screen_y, 0))
    local hits = UnityEngine.Physics.RaycastAll(ray, 1000)
    if not hits then
        return
    end

    for i = 0, hits.Length - 1 do
        local hit = hits[i]
        if hit.collider and hit.collider.gameObject:CompareTag("floor") then
            printf("Ground click: tx=" .. tostring(hit.point.x) .. ", tz=" .. tostring(hit.point.z))
            return
        end
    end
end

local function LoadUIPanel()
    local allui = GameObject.Find("ALLUI")
    local canvas = allui and allui.transform:Find("Canvas") or nil
    local ui = canvas and canvas:Find("UI") or nil

    scene_root = ui and ui:Find("SceneRoot") or nil
    if not scene_root then
        local root_go = GameObject("SceneRoot")
        root_go.transform:SetParent(ui)
        scene_root = root_go.transform
        scene_root.localPosition = Vector3.zero
    else
        scene_root = scene_root.transform
    end
end

-- ============================================================
-- 公开接口
-- ============================================================

function scene_panel.init()
    LoadUIPanel()

    scene_camera = GameObject.Find("MainCamera")
    if not scene_camera then
        scene_camera = GameObject.FindObjectOfType(typeof(Camera))
    end
    update_camera_position()

    scene_panel.set_target_pos(nil, true)
    is_dragging = false
end

-- ============================================================
-- 场景业务逻辑（由 mod_scene 协议回调触发）
-- ============================================================

function scene_panel.EnterScene(pos, objs, troops, tank)
    __in_scene = true
    scene_panel.set_target_pos(pos, true)

    __obj_data = {}
    if objs then
        for _, obj in pairs(objs) do
            __obj_data[obj.id] = obj
            scene_panel.ApplyBattleCircle(obj)
        end
    end
    if tank and tank.id then
        __obj_data[tank.id] = tank
        scene_panel.ApplyBattleCircle(tank)
    end
    sync_objects()

    if tank and tank.id then
        local_tank_id = tank.id
        move_smoother.SetLocalTankId(tank.id)
        move_smoother.EnablePrediction(true)
        if tank.pos then
            move_smoother.OnServerPos(tank.pos, true)
        end
        tank_follow_mode = "self"
    else
        move_smoother.EnablePrediction(false)
        tank_follow_mode = nil
    end
    update_camera_position()
end

function scene_panel.UpdateSlices(objs)
    if objs then
        for _, obj in pairs(objs) do
            __obj_data[obj.id] = obj
            scene_panel.ApplyBattleCircle(obj)
        end
    end
    sync_objects()
end

function scene_panel.AddObj(obj)
    if not obj then return end
    __obj_data[obj.id] = obj
    sync_objects()
    scene_panel.ApplyBattleCircle(obj)
end

function scene_panel.AddTank(obj)
    if not obj then return end
    if obj.role_id ~= watchdog.get_role_id() then
        return
    end
    __obj_data[obj.id] = obj
    sync_objects()

    local_tank_id = obj.id
    move_smoother.SetLocalTankId(obj.id)
    move_smoother.EnablePrediction(true)
    if obj.pos then
        local_tank_pos = obj.pos
        move_smoother.OnServerPos(obj.pos, true)
    end
    scene_panel.ApplyBattleCircle(obj)
end

function scene_panel.SyncTank(obj)
    if not obj then return end
    if obj.role_id ~= watchdog.get_role_id() then
        return
    end
    __obj_data[obj.id] = obj
    if obj.pos then
        local_tank_pos = obj.pos
        move_smoother.OnServerPos(obj.pos, true)
    end
    scene_panel.ApplyBattleCircle(obj)
end

function scene_panel.OnSliceLeave(obj)
    if not obj then return end
    local go = __go_map[obj.id]
    if go then
        GameObject.Destroy(go)
        __go_map[obj.id] = nil
        move_smoother.Remove(obj.id)
    end
    __obj_data[obj.id] = nil
end

-- ============================================================
-- 战斗状态转圈圈
-- ============================================================

--- 根据对象 state 决定是否开始/结束转圈圈
function scene_panel.ApplyBattleCircle(obj)
    if not obj or not obj.id then return end
    local is_battle = obj.state == k_scene_state_battle
    if is_battle then
        if not __battle_circle[obj.id] then
            local cur = move_smoother.GetCurrentPos(obj.id)
            local tx, tz
            if cur then
                tx, tz = cur.tx, cur.tz
            else
                tx, tz = (obj.pos and obj.pos.tx) or 0, (obj.pos and obj.pos.tz) or 0
            end
            __battle_circle[obj.id] = {
                origin_tx = tx,
                origin_tz = tz,
                start_time = os.time(),
                angle = 0,
            }
        end
    else
        __battle_circle[obj.id] = nil
    end
end

function scene_panel.LeaveScene()
    for id, go in pairs(__go_map) do
        if go then
            GameObject.Destroy(go)
        end
    end
    __go_map = {}
    __obj_data = {}
    move_smoother.ClearAll()
    move_smoother.ResetPrediction()
    scene_panel.set_target_pos(nil, true)
    is_dragging = false
    local_tank_id = nil
    local_tank_pos = nil
    tank_follow_mode = nil
    tank_move_dir = nil
    tank_move_timer = 0
    __in_scene = false
    __battle_circle = {}
end

function scene_panel.get_troop(index)
    for id, obj in pairs(__obj_data) do
        if obj.type == k_scene_type_troop and obj.role_id == watchdog.get_role_id() and index == obj.index then
            return obj
        end
    end
    return nil
end

-- ============================================================
-- 场景状态查询
-- ============================================================

function scene_panel.SetScenePos(tx, tz)
    __scene_pos.tx = tx
    __scene_pos.tz = tz
end

function scene_panel.SetTankFollowMode(mode)
    printf("[SetTankFollowMode] old=" .. tostring(tank_follow_mode) .. " new=" .. tostring(mode) .. " local_tank_pos=" .. tostring(local_tank_pos ~= nil))
    tank_follow_mode = mode
    if mode == "tank" and local_tank_id then
        local pos = move_smoother.GetCurrentPos(local_tank_id) or move_smoother.GetPredictPos()
        if pos then
            scene_panel.set_target_pos({ tx = pos.tx, tz = pos.tz }, true)
        end
    end
end

function scene_panel.GetTankFollowMode()
    return tank_follow_mode
end

function scene_panel.is_in_scene()
    return __in_scene
end

function scene_panel.get_scene_pos()
    return __scene_pos
end

function scene_panel.get_scene_objs()
    return __obj_data
end

function scene_panel.get_last_slice()
    return __last_slice_x, __last_slice_z
end

local function calc_slice(tx, tz)
    return math.floor((tx or 0) / 50), math.floor((tz or 0) / 50)
end

local function try_send_slices()
    if not __in_scene then
        return
    end
    local slice_x, slice_z = calc_slice(__scene_pos.tx, __scene_pos.tz)
    if slice_x ~= __last_slice_x or slice_z ~= __last_slice_z then
        __last_slice_x = slice_x
        __last_slice_z = slice_z
        local slices_proto = Proto.new("m_scene_slices_tos", "pos", {tx = __scene_pos.tx, tz = __scene_pos.tz})
        send_to_server(watchdog.get_id(), Proto.pack(slices_proto))
    end
end

local function try_notify_slice_change()
    local old_slice_x, old_slice_z = __last_slice_x, __last_slice_z
    local new_slice_x, new_slice_z = calc_slice(view_target_pos.tx, view_target_pos.tz)
    if new_slice_x ~= old_slice_x or new_slice_z ~= old_slice_z then
        scene_panel.SetScenePos(view_target_pos.tx, view_target_pos.tz)
        try_send_slices()
    end
end

function scene_panel.TrySendSlices()
    try_send_slices()
end

function scene_panel.TrySendMarch(index, target_id, pos)
    printf("TrySendMarch index: %d, target_id: %d, pos: %s", index, target_id, vardump(pos))
    local proto = Proto.new("m_scene_march_tos", "troop_index", index, "target_id", target_id, "pos", pos)
    send_to_server(watchdog.get_id(), Proto.pack(proto))
end

function scene_panel.set_target_pos(new_pos, ignore_notify)
    view_target_pos = new_pos
    update_camera_position()
    if not ignore_notify and new_pos then
        try_notify_slice_change()
    end
end

local function update_target_pos_fields(tx, tz)
    view_target_pos.tx = tx
    view_target_pos.tz = tz
    update_camera_position()
    try_notify_slice_change(tx, tz)
end

-- 保留可更新按钮回调接口
function scene_panel.Update()
    if not scene_panel.is_in_scene() then
        return
    end

    local is_tank_mode = (tank_follow_mode == "tank")

    if is_tank_mode then
        local dirs = {}
        if Input.GetKey(CS.UnityEngine.KeyCode.W) or Input.GetKey(CS.UnityEngine.KeyCode.UpArrow) then
            dirs[#dirs + 1] = "forward"
        end
        if Input.GetKey(CS.UnityEngine.KeyCode.S) or Input.GetKey(CS.UnityEngine.KeyCode.DownArrow) then
            dirs[#dirs + 1] = "backward"
        end
        if Input.GetKey(CS.UnityEngine.KeyCode.A) or Input.GetKey(CS.UnityEngine.KeyCode.LeftArrow) then
            dirs[#dirs + 1] = "left"
        end
        if Input.GetKey(CS.UnityEngine.KeyCode.D) or Input.GetKey(CS.UnityEngine.KeyCode.RightArrow) then
            dirs[#dirs + 1] = "right"
        end
        tank_move_dir = dirs

        tank_move_timer = tank_move_timer + (CS.UnityEngine.Time.deltaTime or 0.016)
        if tank_move_timer >= TANK_MOVE_INTERVAL and #tank_move_dir > 0 then
            -- 战斗状态不下发移动协议，只做本地转圈圈动画
            if not __battle_circle[local_tank_id] then
                Main.send_tank_move(tank_move_dir)
            end
            move_smoother.OnLocalMove(tank_move_dir, TANK_STEP)
            tank_move_timer = 0
        end

        update_camera_position()
    else
        if Input:GetMouseButtonDown(0) then
            is_dragging = true
            mouse_down_pos_x = Input.mousePosition.x
            mouse_down_pos_y = Input.mousePosition.y
        end

        if is_dragging then
            local delta_x = -Input.GetAxis("Mouse X") * DRAG_SPEED_X
            local delta_y = Input.GetAxis("Mouse Y") * DRAG_SPEED_Y

            if view_target_pos then
                local new_tx = view_target_pos.tx + delta_x
                local new_tz = view_target_pos.tz - delta_y

                new_tx = math.max(0, math.min(2000, new_tx))
                new_tz = math.max(0, math.min(2000, new_tz))

                update_target_pos_fields(new_tx, new_tz)
            end
        end

        if Input:GetMouseButtonUp(0) then
            is_dragging = false
            local up_x = Input.mousePosition.x
            local up_y = Input.mousePosition.y
            local dx = up_x - mouse_down_pos_x
            local dy = up_y - mouse_down_pos_y
            if dx * dx + dy * dy < CLICK_MOVE_THRESHOLD * CLICK_MOVE_THRESHOLD then
                try_click_ground(up_x, up_y)
            end
        end
    end

    move_smoother.Update()
    for id, go in pairs(__go_map) do
        if id == local_tank_id then
            local pred = move_smoother.GetPredictPos()
            if pred then
                go.transform.position = world_to_screen_pos(pred.tx, pred.tz)
                if tank_follow_mode == "tank" then
                    scene_panel.set_target_pos({ tx = pred.tx, tz = pred.tz })
                end
            end
            if tank_move_dir and #tank_move_dir > 0 then
                local nx, nz = move_smoother.CalcFacingFromDirs(tank_move_dir)
                if nx ~= 0 or nz ~= 0 then
                    local y_angle = math.atan(nx, nz) * (180 / math.pi)
                    go.transform.rotation = Quaternion.Euler(0, y_angle, 0)
                end
            end
        else
            local cur = move_smoother.GetCurrentPos(id)
            if cur then
                go.transform.position = world_to_screen_pos(cur.tx, cur.tz)
            end
        end
    end

    -- 战斗状态转圈圈：每帧计算并覆盖插值目标
    for id, circle in pairs(__battle_circle) do
        local elapsed = os.time() - circle.start_time
        local rad = (circle.angle + elapsed * BATTLE_CIRCLE_SPEED) * (math.pi / 180)
        local tx = circle.origin_tx + BATTLE_CIRCLE_RADIUS * math.cos(rad)
        local tz = circle.origin_tz + BATTLE_CIRCLE_RADIUS * math.sin(rad)
        move_smoother.SetTarget(id, {tx = tx, tz = tz})
        local go = __go_map[id]
        if go then
            go.transform.position = world_to_screen_pos(tx, tz)
        end
    end
end

function scene_panel.OnClose()
    for id, go in pairs(__go_map) do
        if go then
            GameObject.Destroy(go)
        end
    end
    __go_map = {}
    move_smoother.ClearAll()
    move_smoother.ResetPrediction()
    local_tank_id = nil
    scene_root = nil
    scene_camera = nil
    scene_panel.set_target_pos(nil, true)
    is_dragging = false
    tank_follow_mode = nil
    local_tank_pos = nil
    tank_move_dir = nil
    tank_move_timer = 0
    __in_scene = false
    __battle_circle = {}
end


return scene_panel
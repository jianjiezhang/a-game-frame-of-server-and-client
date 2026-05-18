--- move_smoother：移动插值与预测纠偏模块
-- 所有 lerp 插值和 prediction+correction 逻辑集中在此，供外部调用。
local move_smoother = {}

-- ============================================================
-- 公共配置（默认值，可通过 SetConfig 覆盖）
-- ============================================================
local cfg = {
    enable_prediction = false,   -- 是否启用预测
    lerp_speed = 20,             -- lerp 插值速度系数（每帧目标差 * speed，值越大跟随越快）
    correct_threshold = 1.5,     -- 纠偏阈值（格），预测位置与服务器位置差超过此值则强制纠偏
    correct_lerp_speed = 10,     -- 纠偏时 lerp 到目标的速度
}

function move_smoother.SetConfig(key, value)
    cfg[key] = value
end

function move_smoother.GetConfig(key)
    return cfg[key]
end

-- ============================================================
--  Part 1: Lerp 插值系统
-- ============================================================

-- 对象插值数据：{ current = {tx,tz}, target = {tx,tz}, speed = number }
local lerp_objects = {}

--- 设置插值目标。
-- @param id        对象唯一标识（数字或字符串）
-- @param target    目标位置 {tx=, tz=}
-- @param speed     可选，覆盖默认 lerp_speed
function move_smoother.SetTarget(id, target, speed)
    if not id or not target then return end
    local obj = lerp_objects[id]
    if not obj then
        lerp_objects[id] = {
            current = { tx = target.tx, tz = target.tz },
            target  = { tx = target.tx, tz = target.tz },
            speed   = speed or cfg.lerp_speed,
        }
    else
        obj.target.tx = target.tx
        obj.target.tz = target.tz
        if speed then
            obj.speed = speed
        end
    end
end

--- 立即将对象 current/target 都设到指定位置（跳过插值直接到位）
function move_smoother.SetPosition(id, pos)
    if not id or not pos then return end
    lerp_objects[id] = {
        current = { tx = pos.tx, tz = pos.tz },
        target  = { tx = pos.tx, tz = pos.tz },
        speed   = cfg.lerp_speed,
    }
end

--- 获取对象当前插值后的位置（用于设置 GameObject）
-- @return pos {tx=, tz=} 或 nil
function move_smoother.GetCurrentPos(id)
    local obj = lerp_objects[id]
    return obj and obj.current or nil
end

--- 移除插值中的对象
function move_smoother.Remove(id)
    lerp_objects[id] = nil
end

--- 清空所有插值数据
function move_smoother.ClearAll()
    lerp_objects = {}
end

--- 每帧调用，更新所有对象的插值位置。
-- @param deltaTime 帧间隔（秒）
function move_smoother.Update(deltaTime)
    local dt = deltaTime or (CS.UnityEngine.Time and CS.UnityEngine.Time.deltaTime) or 0.016
    for id, obj in pairs(lerp_objects) do
        local cur = obj.current
        local tgt = obj.target
        local dist = math.sqrt((tgt.tx - cur.tx) ^ 2 + (tgt.tz - cur.tz) ^ 2)
        if dist < 0.001 then
            -- 足够接近，直接到位
            cur.tx, cur.tz = tgt.tx, tgt.tz
        else
            -- 每帧 lerp：target - current 差值，乘以 speed * dt，限制不超过剩余距离
            local t = math.min(1, obj.speed * dt)
            cur.tx = cur.tx + (tgt.tx - cur.tx) * t
            cur.tz = cur.tz + (tgt.tz - cur.tz) * t
        end
    end
end

-- ============================================================
--  Part 2: Prediction + Correction 系统（用于本地 Tank）
-- ============================================================

-- 预测状态
local predict = {
    enabled       = false,
    local_tank_id = nil,     -- 本地操作的 tank 对象 id
    -- 服务器权威位置（最新收到服务器推送的位置）
    server_pos   = nil,   -- {tx=, tz=}
    -- 预测的本地位置（服务器未来到之前的本地预测位置）
    predicted_pos = nil,  -- {tx=, tz=}
    -- 是否已收到服务器第一次确认
    server_confirmed = false,
}

--- 设置本地 tank 的对象 id（用于区分本地 correction 和远程 lerp）
function move_smoother.SetLocalTankId(id)
    predict.local_tank_id = id
end

function move_smoother.GetLocalTankId()
    return predict.local_tank_id
end

--- 计算方向数组对应的归一化朝向向量
-- @param dirs 方向数组
-- @return nx, nz 归一化朝向，无有效方向时返回 0, 0
function move_smoother.CalcFacingFromDirs(dirs)
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
        local len = math.sqrt(dx * dx + dz * dz)
        return dx / len, dz / len
    end
    return 0, 0
end

--- 启用/停用预测系统
function move_smoother.EnablePrediction(enabled)
    predict.enabled = enabled
end

--- 当收到服务器位置推送时调用（correction）
-- @param server_pos 服务器下发的新位置 {tx=, tz=}
-- @param is_local   true=本局操作的tank，走prediction路径；false=其他对象，走普通lerp
function move_smoother.OnServerPos(server_pos, is_local)
    if not server_pos then return end
    local pos = { tx = server_pos.tx, tz = server_pos.tz }

    if not is_local or not predict.enabled then
        -- 预测未启用或非本地tank：走普通lerp路径
        predict.server_pos = pos
        predict.server_confirmed = true
        return
    end

    local prev_server = predict.server_pos
    predict.server_pos = pos

    if not predict.server_confirmed then
        -- 首次收到服务器确认，直接同步
        predict.predicted_pos = { tx = pos.tx, tz = pos.tz }
        predict.server_confirmed = true
        return
    end

    -- 对比预测位置与服务器位置，决定是否纠偏
    local pred = predict.predicted_pos or prev_server or pos
    local dx = pos.tx - pred.tx
    local dz = pos.tz - pred.tz
    local diff = math.sqrt(dx * dx + dz * dz)

    if diff > cfg.correct_threshold then
        -- 偏差超阈值，强制纠偏
        predict.predicted_pos = { tx = pos.tx, tz = pos.tz }
    end
end

--- 当本地发送移动指令时调用（prediction）
-- @param dirs        方向数组 ["forward","left"] 等
-- @param step        每步移动量（格），默认 0.4
function move_smoother.OnLocalMove(dirs, step)
    if not predict.enabled or not predict.server_confirmed then
        return
    end
    step = step or 0.4
    local pos = predict.predicted_pos
    if not pos then
        pos = predict.server_pos
    end
    if not pos then return end

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
        local len = math.sqrt(dx * dx + dz * dz)
        local nx, nz = dx / len, dz / len
        pos.tx = pos.tx + nx * step
        pos.tz = pos.tz + nz * step
        pos.tx = math.max(0, math.min(2000, pos.tx))
        pos.tz = math.max(0, math.min(2000, pos.tz))
        predict.predicted_pos = pos
    end
end

--- 每帧调用，获取当前用于渲染的位置。
-- @return {tx=, tz=}
function move_smoother.GetPredictPos()
    if not predict.enabled or not predict.server_confirmed then
        return predict.server_pos
    end
    return predict.predicted_pos or predict.server_pos
end

--- 重置预测状态（进入新场景时调用）
function move_smoother.ResetPrediction()
    predict.server_pos = nil
    predict.predicted_pos = nil
    predict.server_confirmed = false
    predict.local_tank_id = nil
end

return move_smoother

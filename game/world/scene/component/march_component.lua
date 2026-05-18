-- 行军组件
march_component = {}
march_component.__parent = base_component
march_component.__index = march_component

function march_component:new(owner, ...)
    local tab = self.__parent:new(k_scene.KSCENE_COMPONENT_TYPE_MARCH, owner, ...)
    setmetatable(tab, self)
    return tab
end

function march_component:start(obj, target_id, pos)
    self.target_id = target_id or 0
    self.target_pos = pos or nil
    self.last_tick_time = stdin.time()
    obj.state = k_scene.KSCENE_STATE_MARCH
    obj:update_pobj()
    obj:push_component(self)
    scene_collision.register(obj)

    local conf = scene.find_config(scene.get_typeid())
    local tick_ms = (conf and conf.march and conf.march.tick_ms) or 100
    local now = stdin.time()
    skynet.timer_push_ends(march_component.check_tick, now + tick_ms, obj.id)
    skynet.warn("march_component:start target_id: %d, pos: %s", target_id, skynet.vardump(pos))
    return true
end

function march_component:tick(obj_id)
    local obj = scene_objmgr.get(obj_id)
    if not obj or obj.state ~= k_scene.KSCENE_STATE_MARCH then
        return
    end

    local target_pos
    if self.target_id and self.target_id ~= 0 then
        local target_obj = scene_objmgr.get(self.target_id)
        if not target_obj then
            self:stop(obj)
            skynet.warn("march_component:tick target_obj not found, obj_id: %d", obj_id)
            return
        end
        target_pos = target_obj.pos
    else
        target_pos = self.target_pos
    end

    if not target_pos then
        skynet.warn("march_component:tick target_pos not found, obj_id: %d", obj_id)
        self:stop(obj)
        return
    end

    local dx = target_pos.tx - obj.pos.tx
    local dz = target_pos.tz - obj.pos.tz
    local dist_2 = dx * dx + dz * dz

    local conf = scene.find_config(scene.get_typeid())
    local stop_dist = (conf and conf.march and conf.march.stop_dist) or 3
    local arrive_dist = (conf and conf.march and conf.march.arrive_dist) or 1
    local speed = (conf and conf.march and conf.march.speed) or 1
    local tick_ms = (conf and conf.march and conf.march.tick_ms)
    local stop_threshold = (self.target_id and self.target_id ~= 0) and stop_dist or arrive_dist

    if dist_2 <= stop_threshold * stop_threshold then
        skynet.warn("march_component:tick dist_2 <= stop_threshold * stop_threshold, obj_id: %d", obj_id)
        self:stop(obj)
        return
    end

    local now = stdin.time()
    local elapsed_sec = now - self.last_tick_time
    self.last_tick_time = now

    local step = speed * elapsed_sec / 100
    local len = math.sqrt(dist_2)
    local nx = dx / len
    local nz = dz / len
    local new_pos = {
        tx = obj.pos.tx + nx * step,
        tz = obj.pos.tz + nz * step,
    }
    scene.move_obj(obj, new_pos)
    obj:update_pobj()

    if now+tick_ms/10 < stdin.time() then
        skynet.warn("march_component:tick time error, now: %d, tick_ms: %d", now, tick_ms/10)
        return
    end
    skynet.timer_push_ends(march_component.check_tick, now + tick_ms/10, obj.id)
end

function march_component:stop(obj)
    if obj._is_stopping_component then
        return
    end
    obj._is_stopping_component = true
    skynet.timer_remove(self.check_tick)
    obj:pop_component(self)
    obj.state = k_scene.KSCENE_STATE_IDLE
    self.target_id = nil
    self.target_pos = nil
    scene_collision.unregister(obj)
    obj:update_pobj()
    scene.broadcast_obj(obj)
    obj._is_stopping_component = nil
end

-- tick 保留静态入口，定时器回调使用，内部取组件实例再转发
function march_component.check_tick(obj_id)
    local obj = scene_objmgr.get(obj_id)
    if not obj then
        return
    end
    local comp = obj:get_component(k_scene.KSCENE_COMPONENT_TYPE_MARCH)
    if comp then
        comp:tick(obj_id)
    end
end

return march_component

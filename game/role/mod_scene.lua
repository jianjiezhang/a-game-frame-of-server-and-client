mod_scene = {}



function mod_scene.send(pid, ...)
    skynet.send(pid, "lua", ...)
end
function mod_scene.call(pid, ...)
    skynet.call(pid, "lua", ...)
end
function mod_scene.lsend(...)
    local pid = role_data.get_scene_pid()
    if pid then
        skynet.send(pid, "lua", "scene",...)
    end
end
function mod_scene.lcall(...)
    local pid = role_data.get_scene_pid()
    if pid then
        return skynet.call(pid, "lua", "scene",...)
    end
end
function mod_scene.send_world(...)
    local world_pid = scenemgr.get_world_pid()
    mod_scene.send(world_pid, ...)
end

function mod_scene.m_scene_slices_tos(args)
    args.id = role_data.get_role_id()
    mod_scene.lsend(args)
end

function mod_scene.m_scene_create_tos(args)
    scenemgr.send(args)
end

function mod_scene.m_scene_move_tos(args)
    args.id = role_data.get_role_id()
    mod_scene.lsend(args)
end

function mod_scene.m_scene_gen_tank_tos(args)
    args.id = role_data.get_role_id()
    mod_scene.lsend(args)
end

function mod_scene.m_scene_tank_move_tos(args)
    args.id = role_data.get_role_id()
    mod_scene.lsend(args)
end

function mod_scene.m_scene_march_tos(args)
    args.id = role_data.get_role_id()
    mod_scene.lsend(args)
end

function mod_scene.m_scene_enter_tos(args)
    mod_scene.auto_leave("change_scene")
    local procname = args.type ~= 0 and (".scene_" .. args.type .. "_" .. args.id) or (".scene_" .. args.id)
    skynet.warn("%s", skynet.vardump(procname))
    args.pid = skynet.self()
    args.id = role_data.get_role_id()
    mod_scene.entered(procname)
    mod_scene.send(procname, "scene", args)
end
function mod_scene.m_scene_leave_tos(args)
    mod_scene.auto_leave("client_leave")
    return 
end

function mod_scene.entered(scene_pid)
    role_data.set_scene_pid(scene_pid)
end
function mod_scene.leaved()
    role_data.set_scene_pid(nil)
end
function mod_scene.auto_leave(reason)
    local pid = role_data.get_scene_pid()
    if pid then
        skynet.warn("scene auto leave, role_id=%s reason=%s pid=%s", role_data.get_role_id(), tostring(reason), tostring(pid))
        mod_scene.send(pid, "scene", "leave", role_data.get_role_id())
    end
    mod_scene.leaved()
end
function mod_scene.leave()
    mod_scene.auto_leave("manual_leave")
end



return mod_scene
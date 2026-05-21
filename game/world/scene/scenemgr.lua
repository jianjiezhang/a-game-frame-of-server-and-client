

scenemgr = {}

local __procname = ".scenemgr"
local __pscenes
local __scenes
local __roles
local __id
local __world_scene

local function get_id()
    __id = __id + 1
    while __id > 0 and __scenes[__id] do
        __id = __id + 1
    end
    if __id < 0 then
        __id = 1
    end
    return __id
end
local function get_scene(id)
    return __scenes[id]
end
local function add_scene(scene)
    __pscenes[scene.pid] = scene
    __scenes[scene.id] = scene
end
local function get_scene_name(typeid)
    if typeid == k_scene.KSCENE_BATTLE then
        return "scene_battle"
    end
    return "scene"
end
local function create_scene(typeid, is_system, ...)
    local conf = f_scene[typeid]
    if not conf then
        return
    end
    local id = get_id()
    local pid = skynet.newservice(get_scene_name(typeid), id, typeid, is_system, ...)
    local scene = {id = id, typeid = typeid, pid = pid}
    add_scene(scene)
    skynet.warn("create_scene:%s", skynet.vardump({id, pid, typeid, is_system, ...}))
    return scene
end
local function del_scene(id)
    local scene = __scenes[id]
    if not scene then       
        return
    end
    __scenes[id] = nil
    __pscenes[scene.pid] = nil
end
local function enter_role(role_id, scene_id)
    __roles[role_id] = get_scene(scene_id)
end
local function leave_role(role_id)
    __roles[role_id] = nil
end

function scenemgr.enter(...)
    scenemgr.send("entern", ...)
end
function scenemgr.entern(role_id, scene_id)
    enter_role(role_id, scene_id)
end
function scenemgr.leave(...)
    scenemgr.send("leaven", ...)
end
function scenemgr.leaven(role_id)
    leave_role(role_id)
end

function scenemgr.send(...)
    skynet.send(__procname, "lua", ...)
end
function scenemgr.call(...)
    return skynet.call(__procname, "lua", ...)
end
function scenemgr.create(...)
    return scenemgr.call("createn", ...)
end
function scenemgr.create_battle(...)
    return scenemgr.call("createn", k_scene.KSCENE_BATTLE, true, ...)
end
function scenemgr.testn()
    return "testn"
end
function scenemgr.test()
    return scenemgr.call("testn")
end
function scenemgr.createn(typeid, is_system, ...)
    local scene = create_scene(typeid, is_system, ...)
    if not scene then
        return false
    end
    return scene
end
function scenemgr.create_world()
    return scenemgr.createn(k_scene.KSCENE_WORLD, true)
end
function scenemgr.stop_scene(...)
    return scenemgr.call("stop_scenen", ...)
end
function scenemgr.stop_scenen(id)
    del_scene(id)
    return true
end
function scenemgr.get_world_pid()
    if not __world_scene then
        return
    end
    return __world_scene.pid
end
function scenemgr.get_role_scene(role_id)
    return __roles[role_id]
end
function scenemgr.get_role_scene_pid(role_id)
    local role_scene = scenemgr.get_role_scene(role_id)
    if role_scene then
        return role_scene.pid
    end
end

function scenemgr.m_scene_create_tos(args)
    local typeid = args.typeid or args.scene_id
    if not typeid then
        return
    end
    local scene = scenemgr.createn(typeid)
    if not scene then
        return false
    end
    return true, "scene", scene
end








if SERVICE_NAME == "scenemgr" then
    
function scenemgr.init()
    skynet.register(__procname)
    skynet.dispatch("lua", skynet.dispatch_lua, scenemgr)
    __scenes = {}
    __pscenes = {}
    __roles = {}
    __id = 0
    __world_scene = scenemgr.create_world()
end
function scenemgr.GETLOG()
    return "[scenemgr]:"
end

end










return scenemgr



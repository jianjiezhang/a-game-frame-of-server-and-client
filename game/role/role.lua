


local socket = require "socket"
local mysql = require "mysql"
local __procname = ".role"
role = {}
local last_save_time
local __save_time = 20
local last_exit_time
local __exit_intvl = 30

--=========================local =======================

local function handle_proto(proto, ok, result, ...)
    if not ok then
        skynet.error("handle proto false:",skynet.vardump(proto)," error:" ,result)
        return skynet.send_protofe(proto.__name, "error", 51)
    end
    if  result == nil then
        return
    end
    skynet.send_protofe(proto.__name, ...)
end

--=============================protocol

function role.m_role_echo_tos(args)
    return true, "content", args.content
end
function role.m_role_content_tos(args)
    role_data.set_content(args.content)
    return true
end
function role.m_role_heartbeat_tos(args)
    last_heartbeat_time = stdin.time_s()
    return true
end

function role.m_role_info_tos(args)
    return true, "role", role_data.get_role(), "content", role_data.get_content()
end

--============================public============================

function role.GETLOG()
    local role = role_data.get_role()
    if role and role.id then
        return "[role ".. role.id .. "]:" 
    end
    return "[role]:"
end

function role.send_proto(proto)
    skynet.send_proto(proto)
end
function role.handle(proto)
    local mod, method = Proto.mod(proto.__mod), proto.__name
    --if not ok then
    --    return handle_proto(proto, true, false, "error", 1)
    --end
    local mm = _G[mod][method]
    if not mm then
        return handle_proto(proto, true, false, "error", 2)
    end
    return handle_proto(proto, xpcall(mm, debug.traceback, proto))
end

function role.connected(gate_pid, newrole)
    skynet.error("客户端连接")
    role_data.set_gatepid(gate_pid)
    role.login(newrole)
    role_data.set_state(k_role.KROLE_STATE_ONLINE)
end
function role.reconnected()
    skynet.error("客户端重连")
    last_exit_time = nil
    role_data.set_state(k_role.KROLE_STATE_ONLINE)
end
function role.disconnected()
    skynet.error("客户端断连")
    last_exit_time = stdin.time_s()
    role_data.set_state(k_role.KROLE_STATE_DISCONNECTED)
end

function role.check(args)
    local time = stdin.time_s()

    if time - last_save_time > __save_time then
        role.save()
        last_save_time = time
    end

    if last_exit_time and time - last_exit_time > __exit_intvl then
        skynet.exit_service()
        last_exit_time = time
    end 

    local now = stdin.time()
    skynet.timer_push_ends(role.check, now + 500, now + 500)
end

function role.login(newrole)
    role_data.set_state(k_role.KROLE_STATE_LOGINING)
    skynet.register(".role_" .. newrole.id)
    last_save_time = 0

    role_cache.start(newrole) --系统数据启动
    role.check()
end

function role.save()
    local role = role_data.get_role()
    db.write("t_role",role)
end
function role.stop()
    skynet.error("role stop....:",skynet.vardump(role_data.get_role_id()))
    role_data.set_state(k_role.KROLE_STATE_offing)
    role.save()
    role_data.set_state(k_role.KROLE_STATE_DESTROYED)
    skynet.send(role_data.get_gatepid(), "lua", "gate", "logout", role_data.get_role_id())
    skynet.catch(role_hook.role_stop)
end

if SERVICE_NAME == "role" then
    function role.init(conf)
        skynet.dispatch("lua", skynet.dispatch_lua)
        skynet.timer_init()
        role_data.set_state(k_role.KROLE_STATE_INIT)
    end
end

return role



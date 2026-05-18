


gate = {}



local __gate_id

local __roles
local __socks
local __hb_times
local __heart_intvl = 10
--=================local===================



--=================public====================
function gate.GETLOG()
    if not __gate_id then
        return "[gate]:"
    end
    return "[gate " .. __gate_id .. "]:"
end

function gate.send_proto(role_id, proto)
    local fd = __roles[role_id].fd
    if not fd then
        return
    end
    socket.send_proto(fd, proto)
end

function gate.recv_proto(fd)
    return socket.recv_proto(fd)
end


function gate.heartbeat(fd)
    __hb_times[fd] = stdin.time_s()
end

function gate.client_loop(fd)
    socket.start(fd)
    while true do
        local proto = gate.recv_proto(fd)
        if not proto then
            skynet.error("Client disconnected:",skynet.vardump(fd))
            gate.network_disconnected(fd, "无法获取协议")
            break
        end
        if proto.__name == "m_role_heartbeat_tos" then
            gate.heartbeat(fd)
        else
            local role = __socks[fd]
            skynet.send(role.handle_id, "lua", "role", "handle", proto)
        end
    end
end

function gate.add_role(role_id, fd, handle_id)
    __roles[role_id] = {role_id = role_id, fd = fd, handle_id = handle_id}
    __socks[fd] = __roles[role_id]
    __hb_times[fd] = stdin.time_s()
end
function gate.del_role(role_id)
    local role = __roles[role_id]
    if role and role.fd then
        gate.del_sock(role_id)
    end
    __roles[role_id] = nil
end
function gate.add_sock(role_id, fd)
    local role = __roles[role_id]
    role.fd = fd
    __socks[fd] = role
    __hb_times[fd] = stdin.time_s()
end
function gate.del_sock(role_id)
    local role = __roles[role_id]
    local fd = role.fd
    __socks[fd] = nil
    __hb_times[fd] = nil
    role.fd = nil
    socket.close(fd)
end

function gate.enter_role(fd, role) --客户端连接
    if __roles[role.id] then
        skynet.error("gatemgr操作错误:", skynet.vardump(fd, role, __roles[role.id]))
        return
    end
    local handle_id = skynet.newservice("role")
    if not handle_id then
        skynet.error("玩家进程启动失败...:",skynet.vardump(role.id, handle_id))
        gatemgr.send("enter_failed", role.id)
        socket.close(fd)
        return
    end

    gate.add_role(role.id, fd, handle_id)
    skynet.fork(gate.client_loop, fd)
    gatemgr.send("add_role", __gate_id, fd, role.id)
    skynet.send(handle_id, "lua", "role", "connected", skynet.self(), role)

    local proto = Proto.new("m_watchdog_auth_toc", "result", true, "role_id", role.id)
    gate.send_proto(role.id, proto)
end

function gate.reenter_role(fd, role_id) --客户端重连/顶号
    if not __roles[role_id] then
        skynet.error("服务已停止,无法重连...")
        socket.close(fd)
        return
    end
    if __roles[role_id].fd then
        gate.remote_disconnected(__roles[role_id].fd, "顶号")
        skynet.error("远程成功断连....")
    end

    gate.add_sock(role_id, fd)
    skynet.fork(gate.client_loop, fd)
    skynet.send(__roles[role_id].handle_id, "lua", "role", "reconnected")

    local proto = Proto.new("m_watchdog_auth_toc", "result", true, "role_id", role_id)
    gate.send_proto(role_id, proto)
end

function gate.disconnected(role_id)
    gate.del_sock(role_id)
end

function gate.network_disconnected(fd, errno) --网络原因断开连接
    local role = __socks[fd]
    if not role then
        return
    end
    skynet.error(role.role_id, "网络原因断开连接:", errno or "通用原因")
    gate.disconnected(role.role_id)
    skynet.send(role.handle_id, "lua", "role", "disconnected")
end
function gate.remote_disconnected(fd, errno)
    local role = __socks[fd]
    if not role then
        return
    end
    skynet.error(role.role_id, "网络原因断开连接:", errno or "通用原因")
    local proto = Proto.new("m_watchdog_remote_toc")
    gate.send_proto(role.role_id, proto)
    
    gate.disconnected(role.role_id)
    
    skynet.send(role.handle_id, "lua", "role", "disconnected")
end
function gate.role_disconnected(role_id, errno) --玩家主动下线
    gate.disconnected(role_id)
    skynet.error(role_id, "网络原因断开连接:", errno or "通用原因")
end

function gate.logout(role_id) --玩家真正下线(进程销毁)
    local fd, role_id, handle_id = __roles[role_id].fd, __roles[role_id].role_id, __roles[role_id].handle_id
    skynet.error("gate logout:", skynet.vardump(fd, role_id, handle_id))
    gate.del_role(role_id)
    gatemgr.send("del_role", __gate_id, role_id)
end

function gate.check()
    local time = stdin.time_s()
    for fd, last_time in pairs(__hb_times) do
        if time - last_time > __heart_intvl then
            gate.network_disconnected(fd, "心跳断开")
        end
    end

    local now = stdin.time()
    skynet.timer_push_ends(gate.check, now + 500, now + 500)
end


if SERVICE_NAME == "gate" then
    
function gate.init(id)
    skynet.dispatch("lua", skynet.dispatch_lua)
    skynet.timer_init()
    __gate_id = id
    __roles, __socks, __hb_times = {}, {}, {}
    gate.check()
end

end






return gate
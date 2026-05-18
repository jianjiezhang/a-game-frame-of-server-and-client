gatemgr = {}


local __procname = ".gatemgr"
local __gates
local __roles
local __readys

--===================local====================
local function get_gate()
    local min
    for _, v in pairs(__gates) do
        if not min or min.cnt > v.cnt then
            min = v
        end
    end
    return min
end

--====================public==================
function gatemgr.GETLOG()
    return "[gatemgr]:"
end

function gatemgr.send(...)
    skynet.send(__procname, "lua", "gatemgr", ...)
end
function gatemgr.call(...)
    skynet.call(__procname, "lua", "gatemgr", ...)
end
function gatemgr.apply_gate(fd, role)
    --重连
    if __roles[role.id] then
        local gate_id = __roles[role.id].gate_id
        skynet.send(__gates[gate_id].id, "lua", "gate", "reenter_role", fd, role.id)
        return
    end
    --初次
    local gate = get_gate()
    skynet.send(gate.id, "lua", "gate", "enter_role", fd, role)
    __readys[role.id] = gate.id
end

function gatemgr.enter_failed(role_id)
    __readys[role_id] = nil
end

function gatemgr.add_role(gate_id, fd, role_id)
    __readys[role_id] = nil
    __roles[role_id] = {gate_id = gate_id, role_id = role_id}
    local gate = __gates[gate_id]
    gate.cnt = gate.cnt + 1
    skynet.error("gates,roles:",skynet.vardump(__gates, __roles))
end

function gatemgr.del_role(gate_id, role_id)
    __roles[role_id] = nil
    local gate = __gates[gate_id]
    gate.cnt = gate.cnt - 1
    skynet.error("gates,roles:",skynet.vardump(__gates, __roles))
end

function gatemgr.handle_client(fd, addr)
    skynet.error("client connect:", addr)
    socket.start(fd)

    local proto = socket.recv_proto(fd)
    if not proto or not proto.__name or proto.__name ~= "m_watchdog_auth_tos" or proto.account_id == 0 then
        skynet.error("proto failed:",skynet.vardump(proto))
        socket.close(fd)
        return false
    end
    if proto.user ~= "admin" or proto.password ~= 123456  then
        skynet.error("proto failed2:",skynet.vardump(proto))
        local cproto = Proto.new("m_watchdog_auth_toc", "result", false)
        socket.send_proto(fd, cproto)
        socket.close(fd)
        return false
    end
    local account = db.read("t_account", proto.account_id)
    if not account then 
        account = db.new("t_account", "id", proto.account_id, "name", proto.name)
        local ok, err = db.write("t_account", account)
        if not ok then
            skynet.error("account auth write failed:", skynet.vardump(account, err))
            socket.close(fd)
            return false
        end
    end
    local role
    if proto.role_id == 0 then
        local max_id = db.max("t_role", "id")
        local server_id = skynet.server_id()
        local id = max_id and max_id + 1 or server_id*1000000 + 1
        role = db.new("t_role", "id", id, "name", proto.role_name, "server_id", server_id, "account_id", proto.account_id)
        local ok, err = db.write_new("t_role", role)
        if not ok then
            skynet.error("role write failed:", skynet.vardump(ok, err, role))
            socket.close(fd)
            return false, err
        end
        proto.role_id = id
    elseif not __roles[proto.role_id] then
        role = db.read("t_role", proto.role_id)
        if not role then
            skynet.error("role read failed:", skynet.vardump(proto.role_id))
            socket.close(fd)
            return false
        end
    else
        role = {id = proto.role_id}
    end

    socket.pause(fd)
    socket.abandon(fd)
    gatemgr.apply_gate(fd, role)
end

function gatemgr.start_socket(port)
    local listen_fd = socket.listen("192.168.182.130", port)
    socket.start(listen_fd, function(fd, addr)
        skynet.fork(gatemgr.handle_client, fd, addr)
    end)
    skynet.error("watchdog listen on port:", port)
end

if SERVICE_NAME == "gatemgr" then
    
function gatemgr.init()
    skynet.dispatch("lua", skynet.dispatch_lua)
    gatemgr.start_socket(8894)
    skynet.register(".gatemgr")
    __gates, __roles, __readys = {}, {}, {}
    for i = 1, 3 do
        local handle_id = skynet.newservice("gate", i)
        if handle_id then
            __gates[i] = {id = handle_id, cnt = 0,gate_id = i}
        end
    end
end

end




return gatemgr
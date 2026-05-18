
local socket = require "socket"

watchdog = {}
local CMD = {}
local listen_fd, udp_fd
local connecting_fds = {}

--===================local==================
local function auth(user, pass)
    if user == "admin" and pass == 123456 then
        return true
    end
    return false
end

local function handle_client(fd, addr)
    skynet.error("client connect:", addr)
    socket.start(fd)

    local proto = socket.recv_proto(fd)
    if not proto or not proto.__name or proto.__name ~= "m_watchdog_auth_tos" then
        skynet.error("proto failed:",skynet.vardump(proto))
        socket.close(fd)
        return
    end
    if not watchdog[proto.__name](proto) then
        skynet.error("proto failed2:",skynet.vardump(proto))
        local cproto = Proto.new("m_watchdog_auth_toc", "result", false)
        socket.send_proto(fd, cproto)
        socket.close(fd)
        return
    end

    local role_id = db.read("t_role", "account_id", proto.role_id)
    local handle
    if role_id then
        handle = skynet.localname(".role" .. role_id)
        if not handle then
            handle = skynet.newservice("role")
        end
    end

    socket.pause(fd)
    socket.abandon(fd)
    gatemgr.send("apply_gate", fd, handle, role_id)
    --skynet.send(handle, "lua", "role", proto.__name, proto, fd)
end

--============================public==========================
function watchdog.GETLOG()
    return "[watchdog]:" 
end

function watchdog.m_watchdog_auth_tos(args)
    if not auth(args.user, args.password) then
        return false
    end
    return true
end


if SERVICE_NAME == "watchdog" then

function watchdog.start(port)
    listen_fd = socket.listen("127.0.0.1", port)
    socket.start(listen_fd, function(fd, addr)
        skynet.fork(handle_client, fd, addr)
    end)
    skynet.error("watchdog listen on port:", port)
end

function watchdog.udp_dispatch(data, from)
    skynet.error("data:",data, "  from:",from)
end
function watchdog.start_udp(port)
    udp_fd = socket.udp(function(data, from)
        watchdog.udp_dispatch(data, from)
    end, "127.0.0.1", port)
    skynet.error("watchdog udp listen on port:", port)
end

function watchdog.init()
    skynet.dispatch("lua", skynet.dispatch_lua)
    watchdog.start(8894)
    --watchdog.start_udp(8894)
end
function watchdog.term()
    socket.close(listen_fd)
end

end



return watchdog


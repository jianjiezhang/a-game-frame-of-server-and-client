
consolemgr = {}


if SERVICE_NAME == "consolemgr" then
    
function consolemgr.init()
    local listen_fd = socket.listen("127.0.0.1", 8001)
    socket.start(listen_fd, function(fd, addr)
        skynet.error("Debug connected from " .. addr)
        socket.pause(fd)
        socket.abandon(fd)
        skynet.newservice("console", fd)
    end)
end

end


return consolemgr






local socket = require "client_socket"

local function serialize(value)
    local t = type(value)
    if t == "nil" then
        return "nil"
    elseif t == "number" then
        return tostring(value)
    elseif t == "boolean" then
        return tostring(value)
    elseif t == "string" then
        return string.format("%q", value)
    elseif t == "table" then
        local result = {}
        table.insert(result, "{")
        for k, v in pairs(value) do
            local key
            if type(k) == "string" and k:match("^[_%a][_%w]*$") then
                key = k
            else
                key = "[" .. serialize(k) .. "]"
            end
            table.insert(result, key .. "=" .. serialize(v) .. ",")
        end
        table.insert(result, "}")
        return table.concat(result)
    else
        error("unsupported type:" .. t)
    end
end
local function deserialize(str)
    local func, err = load("return " .. str)
    if not func then
        error("deserialize error:" .. err)
    end
    return func()
end

local fd = socket.connect("127.0.0.1", 8001)
if not fd then
    print("connect failed:", fd)
    return
end

local function check(result)
    if result == "OK!" or string.sub(result, 1, 6) == "NOTOK!" then
        return false
    end
    return true
end

while true do
    --socket.write_stdin("> ")
    local line = socket.read_stdin()
    if line and line ~= "" then
        if line == "exit" or line == "quit" then
            break
        end
        socket.send(fd, line)
        
        local result = socket.recv(fd)
        while check(result) do
            result = string.sub(result, 4, -1)
            io.write(result .. "\n")
            result = socket.recv(fd)
        end
        if result ~= "OK!" then
            io.write(result .. "\n") 
        end 
        --socket.write_stdin(result)
    end
end






































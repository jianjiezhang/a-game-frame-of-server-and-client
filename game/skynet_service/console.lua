
console = {}

local __fd

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
local function capture_print(...)
    local t = {}
    for i = 1, select('#', ...) do
        local val = select(i, ...)
        table.insert(t, tostring(val))
    end
    t = table.concat(t, ",")
    t = "OK!" .. t
    socket.send_packet(__fd, t)
end
--[[local env = {}
for k, v in pairs(_G) do
    env[k] =_G[k]
    if k == "print" then
        env.print = capture_print
    end
end
local mt =getmetatable(_G)
setmetatable(env, mt)
--]]
_G.print = capture_print
function console.handle(fd)
    socket.start(fd)
    while true do
        local cmd = socket.read_packet(fd)
        if not cmd or cmd == "exit" then
            break
        end

        local ok, result = pcall(load(cmd, "shell", "t", _G))
        if not ok then
            socket.send_packet(fd, "NOTOK!" .. tostring(result))
        else
            socket.send_packet(fd, "OK!")
        end
    end
    socket.close(fd)
    skynet.exit()
end


if SERVICE_NAME == "console" then
    
function console.init(fd)
    __fd = fd
    skynet.fork(console.handle, fd)
end

end


return console

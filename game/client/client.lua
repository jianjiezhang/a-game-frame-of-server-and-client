

local socket = require "client_socket"
require "Proto"

local id = ...

local function vardump_(value, pretty, maxDepth, indent, visited)
	indent = indent or 0
	
	visited = visited or {}

	local t = type(value)

	if t == "number" or t == "boolean" then
		return tostring(value)
	elseif t == "string" then
		return string.format("%q",value)
	elseif t == "nil" then
		return "nil"
	elseif t == "table" then
		if maxDepth and indent >= maxDepth then
			return "{...}"
		end

		if visited[value] then
			return "{<circular>}"
		end
		visited[value] = true

		local indentStr = pretty and string.rep("	", indent) or ""
		local nextIndentStr = pretty and string.rep("	", indent + 1) or ""
		local newline = pretty and "\n" or ""
		local space = pretty and " " or ""
		local sep = pretty and ",\n" or ","

		local result = "{"

		if pretty then
			result = result .. newline
		end
		local first = true

		for k, v in pairs(value) do
			if not first then
				result = result .. sep
			end
			first = false

			local keyStr
			if type(k) == "string" and string.match(k, "^[%a_][%w_]*$") then
				keyStr = k
			else
				keyStr = "[" .. vardump_(k, pretty, maxDepth, indent+1, visited) .. "]"
			end

			local valueStr = vardump_(v, pretty, maxDepth, indent + 1, visited)

			if pretty then
				result = result .. nextIndentStr .. keyStr .. space .. "=" .. space .. valueStr
			else
				result = result .. keyStr .. "=" .. valueStr
			end
		end

		if pretty then
			result = result .. newline .. indentStr
		end

		result = result .. "}"

		visited[value] = nil
		return result
	else
		return "\"<unsupported:>" .. t .. ">\""
	end
end
local function vardump(...)
	local tab = {...}
	return vardump_(tab)
end
local function vardump2(...)
	local tab = {...}
	return	vardump_(tab,true)
end

local function recv_proto(fd)
    local data = socket.recv(fd)
    if not data then
        print("read proto failed")
        return false
    end
    --解密+协议
    local proto = Proto.unpack(data)
    print("recv:",vardump(proto))
    return proto
end
local function send_proto(fd, proto)
    print("send:", vardump(proto))
    local data = Proto.pack(proto)
    socket.send(fd, data)
end


local fd = socket.connect("127.0.0.1", 8894)
if not fd then
    print("connect failed:", id)
    return
end

local proto = Proto.new("m_watchdog_auth_tos", "user", "admin", "password", 123456)
send_proto(fd, proto)

recv_proto(fd)

for i = 1, 5 do
    proto = Proto.new("m_role_echo_tos", "content", "hello_" .. i)
    send_proto(fd, proto)
    --recv_proto(fd)
end
local ends = os.time() + 1
while ends >= os.time() do
end

socket.close(fd)


--local udp = socket.udp_create()
--socket.udp_send(udp, "127.0.0.1",8894, "hello")














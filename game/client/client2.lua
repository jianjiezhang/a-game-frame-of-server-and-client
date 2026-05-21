

require "Proto"
require "timer"

local id

local __role
role = {}
watchdog = {}
mod_scene = {}
local CMD = {}
local auth = false
function get_name()
    return "[client " .. id .. "]:"
end
function get_time()
    return "[" .. os.date("%F %T", os.time()) .. "]"
end
function printf(...)
    print(get_time() .. get_name(),...)
end
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
	local str = ""
    for i = 1, select('#', ...) do
        local val = select(i, ...)
        str = str .. vardump_(val) .. ","
    end
    return str
end
local function vardump2(...)
	local str = ""
    for i = 1, select('#', ...) do
        local val = select(i, ...)
        str = str .. vardump_(val, true) .. ","
    end
    return str
end

local function send_proto(id, proto)
    local data = Proto.pack(proto)
    printf("send:", data)
    send_to_server(id, data)
end

function role.echo(content)
    local proto = Proto.new("m_role_echo_tos", "content", content)
    send_proto(id, proto)
end

function role.Heartbeat()
    local proto = Proto.new("m_role_heartbeat_tos")
    send_proto(id, proto)
    timer.push_ends(role.Heartbeat, os.time() + 5)
end

function role.m_role_echo_toc(args)
    printf("recv:",vardump(args))
end
function role.m_role_heartbeat_toc(args)
    printf("recv:",vardump(args))
end
function watchdog.m_watchdog_auth_toc(args)
    printf("recv:", vardump(args))
    if not auth then
        auth = true
    end
    if args.result then
        role.Heartbeat()
    end
end
function watchdog.m_watchdog_remote_toc(args)
    printf("recv:", vardump(args))
    timer.remove(role.Heartbeat)
end
function role.m_role_info_toc(args)
    __role = args.role
    printf("recv:", vardump(args))
end
function role.m_role_content_toc(args)
    printf("recv:", vardump(args))
end
function mod_scene.m_scene_slices_toc(args)
    printf("recv:", vardump(args))
end
function mod_scene.m_scene_enter_toc(args)
    printf("recv:", vardump(args))
end
function mod_scene.m_scene_leave_toc(args)
    printf("recv:", vardump(args))
end


function init(client_id)
    id = client_id and tonumber(client_id)
    timer.init()
    --local proto = Proto.new("m_watchdog_auth_tos", "user", "admin", "password", 123456, "account_id", 1, "name", "HLNB")
    --send_proto(id, proto)
    printf("Lua_client", id, " started!")
end

function on_message(msg)
    local proto = Proto.unpack(msg)
    if not proto.__name then
        printf("invalid proto:", vardump(proto))
    end
    local mod = Proto.mod(proto.__mod)
    local ok, err = xpcall(_G[mod][proto.__name], debug.traceback, proto)
    if not ok then
        printf("proto handle failed:", tostring(err))
    end
end

function on_timer()
    timer.dispatch()
end




function CMD.list()
    local proto = Proto.new("m_role_list_tos", "account_id", 1)
    send_proto(id, proto)
end
function CMD.add_role(name)
    name = name or "HLNB"
    local proto = Proto.new("m_role_add_role_tos", "name", name)
    send_proto(id, proto)
end
function CMD.login(role_id)
    role_id = tonumber(role_id)
    local proto = Proto.new("m_role_login_tos", "id", role_id)
    send_proto(id, proto)
end
function CMD.info()
    local proto = Proto.new("m_role_info_tos")
    send_proto(id, proto)
end
function CMD.content(content)
    local proto = Proto.new("m_role_content_tos", "content", content)
    send_proto(id, proto)
end
--auth,admin,123456,1,HLNB,39000001,HLNB1
function CMD.auth(user, password, account_id,name, role_id, role_name)
    local proto = Proto.new("m_watchdog_auth_tos", "user", user, "password", tonumber(password), "account_id", tonumber(account_id), "name", name, "role_id",tonumber(role_id), "role_name", role_name)
    send_proto(id, proto)
end
function CMD.enter_world()
    local proto = Proto.new("m_scene_enter_tos", "id", 1)
    send_proto(id, proto)
end
function CMD.scene_slices(tx, tz)
    local proto = Proto.new("m_scene_slices_tos", "pos", {tx=tonumber(tx), tz=tonumber(tz)})
    send_proto(id, proto)
end

function CMD.get_id()
    print("id:",tostring(__role.id))    
end

local function split(input, sep)
    sep = sep or ","
    local t = {}
    for str in string.gmatch(input, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end
function on_input(line)
    local parts = split(line, ",")
    printf("on input:",vardump(parts))
    local func = parts[1]
    if not func then
        printf("func not exist")
        return
    end
    table.remove(parts, 1)
    local f = CMD[func]
    if not f then
        printf("func function not exist")
    end
    local ok, err = pcall(f, table.unpack(parts))
    if not ok then
        printf("Err :", err)
    end
end





















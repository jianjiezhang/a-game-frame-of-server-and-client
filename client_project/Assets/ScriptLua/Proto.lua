




Proto = {}

Proto.m_watchdog_auth_tos = {__name = "m_watchdog_auth_tos", __mod = 1, error=0, user = "", password=0, account_id = 0, name= "", role_id = 0, role_name=""}
Proto.m_watchdog_auth_toc = {__name = "m_watchdog_auth_toc", __mod = 1, error = 0, result = false, role_id = 0}
Proto.m_watchdog_remote_toc = {__name = "m_watchdog_remote_toc", __mod = 1, error = 0}
Proto.m_role_echo_tos = {__name = "m_role_echo_tos", __mod = 2, error = 0, content = ""}
Proto.m_role_echo_toc = {__name = "m_role_echo_toc", __mod = 2, error = 0, content = ""}
Proto.m_role_heartbeat_tos = {__name = "m_role_heartbeat_tos", __mod = 2, error = 0}
Proto.m_role_heartbeat_toc = {__name = "m_role_heartbeat_toc", __mod = 2, error = 0}
Proto.m_role_list_tos = {__name = "m_role_list_tos", __mod = 2, error = 0, account_id = 0}
Proto.m_role_list_toc = {__name = "m_role_list_toc", __mod = 2, error = 0, role = {}}
Proto.m_role_add_role_tos = {__name = "m_role_add_role_tos", __mod=2, error = 0, name = ""}
Proto.m_role_add_role_toc = {__name = "m_role_add_role_toc", __mod=2, error = 0, role = {}}
Proto.m_role_login_tos = {__name = "m_role_login_tos", __mod = 2, error = 0, id=0}
Proto.m_role_login_toc = {__name = "m_role_login_toc", __mod = 2, error = 0, role = {}}
Proto.m_role_info_tos = {__name = "m_role_info_tos", __mod = 2, error = 0}
Proto.m_role_info_toc = {__name = "m_role_info_toc", __mod = 2, error = 0, role = {}, content = ""}
Proto.m_role_content_tos = {__name = "m_role_content_tos", __mod=2, error=0, content=""}
Proto.m_role_content_toc = {__name = "m_role_content_toc", __mod=2, error=0, content=""}


Proto.m_scene_create_tos = {__name = "m_scene_create_tos", __mod = 3, error = 0, scene_id = 0}
Proto.m_scene_create_toc = {__name = "m_scene_create_toc", __mod = 3, error = 0, scene = {}}
Proto.m_scene_slices_tos = {__name = "m_scene_slices_tos", __mod = 3, error = 0, pos = {}}
Proto.m_scene_slices_toc = {__name = "m_scene_slices_toc", __mod = 3, error = 0, pos = {}, objs = {}}
Proto.m_scene_move_tos = {__name = "m_scene_move_tos", __mod = 3, error = 0, speed = {}}
Proto.m_scene_hero_info_toc = {__name = "m_scene_hero_info_toc", __mod = 3, error = 0, obj = {}}
Proto.m_scene_enter_tos = {__name = "m_scene_enter_tos", __mod = 3, error = 0, id = 0, type = 0}
Proto.m_scene_enter_toc = {__name = "m_scene_enter_toc", __mod = 3, error = 0, pos = {}, objs = {}, troops = {}, tank = {}}
Proto.m_scene_obj_toc = {__name = "m_scene_obj_toc", __mod = 3, error = 0, obj = {}}
Proto.m_scene_gen_tank_tos = {__name = "m_scene_gen_tank_tos", __mod = 3, error = 0}
Proto.m_scene_gen_tank_toc = {__name = "m_scene_gen_tank_toc", __mod = 3, error = 0, obj = {}}
Proto.m_scene_tank_move_tos = {__name = "m_scene_tank_move_tos", __mod = 3, error = 0, dir = {}}
Proto.m_scene_tank_move_toc = {__name = "m_scene_tank_move_toc", __mod = 3, error = 0, obj = {}}
Proto.m_scene_slice_leave_toc = {__name = "m_scene_slice_leave_toc", __mod = 3, error = 0, obj = {}}
Proto.m_scene_march_tos = {__name = "m_scene_march_tos", __mod = 3, error = 0, troop_index = 0, target_id = 0, pos = {}}
Proto.m_scene_march_toc = {__name = "m_scene_march_toc", __mod = 3, error = 0}


local Module ={}
Module[1] = "watchdog"
Module[2] = "role"
Module[3] = "mod_scene"

local function copy(obj, seen)
	if type(obj) ~= "table" then
		return obj
	end
	seen = seen or {}
	if seen[obj] then
		return seen[obj]
	end
	local new_table = {}
	seen[obj] = new_table

	for k, v in pairs(obj) do
		local new_key = copy(k, seen)
		local new_val = copy(v, seen)
		new_table[new_key] = new_val
	end
	return new_table
end
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
local function spilit(str, delimiter)
    local result = {}
    for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end
local function decode_proto(data)
    local parts = spilit(data, "|")
    local proto = {
        __name = parts[1],
        args = {}
    }
    if parts[2] and parts[2] ~= "" then
        proto.args = spilit(parts[2], ";")
    end
    return proto
end

local function encode_proto(proto)
    --协议+--加密转化
    local args_str = table.concat(proto.args, ";")
    local data = proto.__name .. "|" .. args_str
    return data
end

function Proto.new(name, ...)
    if not Proto[name] then
        return
    end
    local proto = copy(Proto[name])
    for i = 1, select('#', ...), 2 do
        local key, val = select(i, ...)
        proto[key] = val        
    end
    return proto
end

function Proto.transfer(proto)
    local p = Proto.new(proto.__name)
    if not p then
        return false
    end
    for k, v in pairs(p) do
        p[k] = proto[k]
    end
    return p
end
function Proto.pack(proto)
    proto = Proto.transfer(proto)
    local data = serialize(proto)
    return data
end
function Proto.unpack(data)
    local proto = deserialize(data)
    return proto
end

function Proto.mod(mod_index)
    return Module[mod_index]
end




return Proto

























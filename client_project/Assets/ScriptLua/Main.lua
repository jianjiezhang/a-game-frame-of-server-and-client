
-- ============================================================
-- 工具函数
-- ============================================================
function vardump_(value, pretty, maxDepth, indent, visited)
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
function vardump(...)
	local str = ""
    for i = 1, select('#', ...) do
        local val = select(i, ...)
        str = str .. vardump_(val) .. ","
    end
    return str
end
local function printf(fmt, ...)
    print(string.format("[Main] " .. tostring(fmt), ...))
end

-- 设置 _G 元表：访问未定义的全局变量时自动从 ScriptLua 懒加载
local scriptlua_mt = {
    __index = function(_, key)
        printf("require:%s", key)
        local ok, val = pcall(require, key)
        if ok then
            _G[key] = val
            return val
        end
        printf("require:%s ok:%s val:%s", key, ok, val)
        return nil
    end
}
setmetatable(_G, scriptlua_mt)

-- ============================================================
-- 模块定义（必须最早定义，供 role/watcher/mod_scene 直接引用）
-- ============================================================
Main = {}


-- ============================================================
-- 网络发送
-- ============================================================
local function send_proto(proto)
    local data = Proto.pack(proto)
    printf("send:%s", vardump(data))
    send_to_server(watchdog.get_id(), data)
end


-- ============================================================
-- Main 唯一初始化入口
-- ============================================================
function Main.init(init_opts)
    local client_id = init_opts and init_opts.client_id and tonumber(init_opts.client_id) or 1
    watchdog.init(client_id)
    timer.init()
    printf("Lua_client started, client_id=" .. tostring(client_id))

    -- 初始化 scene_panel
    scene_panel.init()

    -- 初始化 proto_panel（调试输入 + 坦克按钮）
    proto_panel.init()

    -- 初始化 login_panel
    login_panel.init()
end

function Main.send_proto(proto)
    send_proto(proto)
end

-- ============================================================
-- 协议消息分发
-- ============================================================
function Main.on_message(msg)
    local proto = Proto.unpack(msg)
    if not proto or not proto.__name then
        printf("invalid proto:", proto)
        return
    end
    local mod = Proto.mod(proto.__mod)
    local ok, err = xpcall(_G[mod][proto.__name], debug.traceback, proto)
    if not ok then
        printf("proto handle failed:%s", tostring(err))
    end
end

-- ============================================================
-- Main 命令
-- ============================================================
function Main.list()
    local proto = Proto.new("m_role_list_tos", "account_id", 1)
    send_proto(proto)
end

function Main.add_role(name)
    name = name or "HLNB"
    local proto = Proto.new("m_role_add_role_tos", "name", name)
    send_proto(proto)
end

function Main.login(role_id)
    role_id = tonumber(role_id)
    local proto = Proto.new("m_role_login_tos", "id", role_id)
    send_proto(proto)
end

function Main.info()
    local proto = Proto.new("m_role_info_tos")
    send_proto(proto)
end

function Main.content(content)
    local proto = Proto.new("m_role_content_tos", "content", content)
    send_proto(proto)
end

function Main.auth(user, password, account_id, name, role_id, role_name)
    watchdog.auth(user, password, account_id, name, role_id, role_name)
end

function Main.enter_world()
    local proto = Proto.new("m_scene_enter_tos", "id", 1)
    send_proto(proto)
end

function Main.scene_slices(tx, tz)
    local proto = Proto.new("m_scene_slices_tos", "pos", {tx = tonumber(tx), tz = tonumber(tz)})
    send_proto(proto)
end

function Main.get_id()
    local r = role and role.get_role and role.get_role()
    if r and r.id then
        print("id:", tostring(r.id))
    else
        print("id: (no role)")
    end
end

-- ============================================================
-- 内部：坦克移动发送（供 scene_panel 回调调用）
-- ============================================================
function Main.send_tank_move(dirs)
    send_proto(Proto.new("m_scene_tank_move_tos", "dir", dirs))
end
-- ============================================================
-- 调试输入处理
-- ============================================================
local function split(input, sep)
    sep = sep or ","
    local t = {}
    for str in string.gmatch(input, "[^" .. sep .. "]+") do
        table.insert(t, str)
    end
    return t
end

function Main.on_input(line)
    local parts = split(line, ",")
    printf("on input:", table.concat(parts, ","))
    local func_name = parts[1]
    if not func_name then
        printf("func not exist")
        return
    end
    table.remove(parts, 1)
    local f = Main[func_name]
    if not f then
        printf("func function not exist")
        return
    end
    local ok, err = pcall(f, table.unpack(parts))
    if not ok then
        printf("Err:", err)
    end
end

-- ============================================================
-- 每帧 tick
-- ============================================================
function Main.update(dt)
    timer.dispatch()

    if proto_panel and proto_panel.Update then
        proto_panel.Update()
    end

    if scene_panel and scene_panel.Update then
        scene_panel.Update()
    end
end

return Main

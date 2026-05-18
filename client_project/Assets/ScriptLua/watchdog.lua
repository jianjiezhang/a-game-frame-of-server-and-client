--- watchdog：网关协议处理
watchdog = {}

local __id = 1
local __role_id = nil
local __auth = false


-- ============================================================
-- 主动发包接口
-- ============================================================
function watchdog.auth(user, password, account_id, name, role_id, role_name)
    local proto = Proto.new("m_watchdog_auth_tos",
        "user", user,
        "password", tonumber(password),
        "account_id", tonumber(account_id),
        "name", name,
        "role_id", tonumber(role_id),
        "role_name", role_name)
    local data = Proto and Proto.pack and Proto.pack(proto)
    send_to_server(__id, data)
end

-- ============================================================
-- 协议回调
-- ============================================================
function watchdog.m_watchdog_auth_toc(args)
    print("[watchdog] recv:", vardump(args))
    if args.result then
        __role_id = args.role_id
        login_panel.OnLoginSuccess()
        __auth = true
        Main.enter_world()
        role.Heartbeat()
    end
end

function watchdog.m_watchdog_remote_toc(args)
    print("[watchdog] recv:", vardump(args))
end

-- ============================================================
-- 查询接口
-- ============================================================
function watchdog.get_id()
    return __id
end

function watchdog.is_auth()
    return __auth
end

function watchdog.get_role_id()
    return __role_id
end

-- ============================================================
-- 设置接口（由 Main.init 调用）
-- ============================================================
function watchdog.set_id(id)
    __id = id or 1
end

function watchdog.init(id)
    watchdog.set_id(id)
end

return watchdog
--- role：角色协议处理
role = {}

require "watchdog"
require "scene_panel"

local __role = nil

-- ============================================================
-- 主动发包接口
-- ============================================================
function role.echo(content)
    local proto = Proto.new("m_role_echo_tos", "content", content)
    send_to_server(watchdog.get_id(), Proto.pack(proto))
end

function role.Heartbeat()
    local proto = Proto.new("m_role_heartbeat_tos")
    send_to_server(watchdog.get_id(), Proto.pack(proto))
    timer.push_ends(role.Heartbeat, os.time() + 5)
end

-- ============================================================
-- 协议回调
-- ============================================================
function role.m_role_echo_toc(args)
    printf("[role] recv:%s", vardump(args))
end

function role.m_role_heartbeat_toc(args)
    printf("[role] recv:%s", vardump(args))
end

function role.m_role_info_toc(args)
    __role = args.role
    printf("[role] recv:%s", vardump(args))
end

function role.m_role_content_toc(args)
    printf("[role] recv:%s", vardump(args))
end

-- ============================================================
-- 只读查询
-- ============================================================
function role.get_role()
    return __role
end


return role

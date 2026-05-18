




role_data = {}

local __gatepid
local __netstate
local __role
local __content
local __scene_pid


function role_data.set_scene_pid(e)
    __scene_pid = e
end
function role_data.get_scene_pid()
    return __scene_pid
end
function role_data.set_content(e)
    __content = e
end
function role_data.get_content()
    return __content
end


function role_data.get_role_id()
    local role = role_data.get_role()
    return role and role.id
end
function role_data.set_role(e)
    __role = e
end

function role_data.get_role()
    return __role
end

function role_data.set_gatepid(e)
    __gatepid = e
end
function role_data.get_gatepid()
    return __gatepid
end

function role_data.get_state()
    return __netstate
end
function role_data.set_state(e)
    __netstate = e
end
function role_data.is_connected()
    return role_data.get_state() == k_role.KROLE_STATE_ONLINE
end





return role_data
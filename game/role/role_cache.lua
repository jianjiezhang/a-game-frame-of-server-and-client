
role_cache = {}

--======================local====================
local function load_role(role)
    role_data.set_role(role)
end



--======================public===================
function role_cache.load_data(role) --加载数据
    load_role(role)
end

function role_cache.init_data(role_id) --运行时数据

end

function role_cache.refresh_data(role_id) --数据规范化检测

end

function role_cache.begin(role_id)  --启动

end

function role_cache.start(role)
    role_cache.load_data(role) --加载数据
    role_cache.init_data(role) --运行时数据
    role_cache.refresh_data(role) --数据规范化检测
    role_cache.begin(role)  --启动
    role_data.set_state(k_role.KROLE_STATE_ONLINE)
end










return role_cache








local codecache = require "skynet.codecache"

adm = {}

local __procname = ".adm"



function adm.hotup(name)
    skynet.warn("热更新文件:%s", name)
    if skynet.is_conf(name) then
        config.load(name)
        return
    end
    local filename, err = skynet.searchpath(name)
    if not filename then
        skynet.warn("热更新有误：%s", skynet.vardump(err))
        return
    end
    codecache.clear()
    adm.broadcast(name)
end
function adm.broadcast(name)
    for address, _ in pairs(skynet.processes()) do
        skynet.send(address, "system", "skynet", "hotup", name)
    end
end

function adm.get_upvalue(pid, ...)
    return skynet.call(pid, "lua", "adm", "get_upvalue2", ...)
end
function adm.get_upvalue2(mod, val_name, ...)
    local mod_obj = package.loaded[mod]
    local tab
    for k, v in pairs(mod_obj) do
        if type(v) == "function" then
            for i = 1, math.huge do
                local name, value = debug.getupvalue(v, i)
                if not name then
                    break
                end
                if name == val_name then
                    tab = value
                    break
                end
            end
        end
        if tab then
            break
        end
    end
    local args = {...}
    for _, v in pairs(args) do
        tab = tab[v]
    end
    return tab
end








if SERVICE_NAME == "adm" then

function adm.init()
    skynet.dispatch("lua", skynet.dispatch_lua)
    skynet.register(__procname)
end

end



return adm
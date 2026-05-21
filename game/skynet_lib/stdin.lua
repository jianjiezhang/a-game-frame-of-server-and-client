
stdin = {}

function stdin.systime()--10ms为一个单位，
    return skynet.now() + skynet.starttime() * 100
end
function stdin.gametime() --游戏时间 
    local intvl = tonumber(skynet.getvenv("intvl"))
    return stdin.systime() + intvl
end

--外部获取游戏时间的接口，10ms为一个单位
function stdin.time() 
    return stdin.gametime()
end

--毫秒级游戏时间
function stdin.time_ms() 
    return stdin.time()*10
end

--秒级游戏时间
function stdin.time_s() 
    return stdin.time()/100
end

--格式化时间
function stdin.date(time)
    time = time or stdin.time_s()
    return os.date("%F %T", time)    
end

--获取文件修改时间
function stdin.get_file_mtime(path)
    local p = io.popen("stat -c %Y " .. path)
    local t = p:read("*l")
    p:close()
    return tonumber(t)
end

--设置表的键值对
function table.setkv(tab, ...)
    for i = 1, select('#', ...), 2 do
        local k = select(i, ...)
        local v = select(i+1, ...)
        tab[k] = v
    end
    return tab
end

function table.mset(tab, tab2)
    for k, v in pairs(tab2) do
        tab[k] = v
    end
    return tab
end


--合并表
function table.append(tab, ntab)
    for _, v in pairs(ntab) do
        table.insert(tab, v)
    end
    return tab
end

return stdin
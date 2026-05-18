


local mysql = require "mysql"


db_service = {}

local DEFAULT_POOL_SIZE = 4

local g_conf
local g_conns = {}
local g_rr = 0
local __procname = ".db_service"

local function is_badresult(res)
    if type(res) ~= "table" then
        return false
    end
    if res.badresult then
        return true
    end
    return false
end

local function do_init(conf)
    g_conf = conf or g_conf or {
        host = "127.0.0.1",
        port = 3306,
        database = "game",
        user = "EVV",
        password = "123456",
        charset = "utf8mb4",
    }

    local pool_size = 4

    g_conns = {}
    g_rr = 0

    for i = 1, pool_size do
        local conn_or_err = mysql.connect(g_conf)
        if not conn_or_err then
            skynet.error("connect failed")
            skynet.exit()
        end
        g_conns[i] = conn_or_err
    end
    return true
end

local function pick_conn()
    local n = #g_conns
    if n <= 0 then
        return nil, "mysql pool not initialized"
    end
    g_rr = g_rr + 1
    local idx = (g_rr - 1) % n +1
    return g_conns[idx]
end

local function query_one(conn, stmt)
    return conn:query(stmt)
end

local function query_multi(conn, sql_or_list)
    if type(sql_or_list) == "table" then
        local results = {}
        for i = 1, #sql_or_list do
            local res = query_one(conn, sql_or_list[i])
            results[i] = res
            if is_badresult(res) then
                results.__multi = true
                return results
            end
        end
        results.__multi = true
        return results
    end
    return query_one(conn, sql_or_list)
end

function db_service.queryn(sql_or_list)
    --skynet.error("queryn:",skynet.vardump(sql_or_list))
    local conn = pick_conn()
    return query_multi(conn, sql_or_list)
end

function db_service.query_atomicn(sql_or_list)
    local conn = pick_conn()
    local begin_result = conn:query("BEGIN")
    if is_badresult(begin_result) then
        return begin_result
    end

    local result = query_multi(conn, sql_or_list)
    local failed = false
    if is_badresult(result) then
        failed = true
    elseif type(result) == "table" then
        for i = 1, #result do
            if is_badresult(result[i]) then
                failed = true
                break
            end
        end     
    end

    if failed then
        conn:query("ROLLBACK")
        return result
    end

    local result_commit = conn:query("COMMIT")
    if is_badresult(result_commit) then
        conn:query("ROLLBACK")
        return result_commit
    end

    return result
end

function db_service.ping()
    local conn = pick_conn()
    return conn:ping()
end

function db_service.query(sql_or_list)
    return skynet.call(__procname, "lua", "db_service", "queryn", sql_or_list)
end
function db_service.query_atomic(sql_or_list)
    return skynet.call(__procname, "lua", "db_service", "query_atomicn", sql_or_list)
end

function db_service.test()
    local result = db_service.query_atomicn("select* from tabdd2;select * from tab1;")
    skynet.error("result:",skynet.vardump(result))
end

if SERVICE_NAME == "db_service" then
function db_service.init()
    skynet.dispatch("lua", skynet.dispatch_lua)
    do_init()
    skynet.register(__procname)
    --db_service.test()
end

end

return db_service


































dbmgr = {}
local db_services = {}
local __procname = ".dbmgr"

local function get_db()
    local result
    for _, v in pairs(db_services) do
        if v.running then
            goto continue
        end
        result = v
        break
        ::continue::
    end
    if not result then
        local i = math.random(#db_services)
        result = db_services[i]  
    end
    return result
end

function dbmgr.query(sql)
    return skynet.call(__procname, "lua", "dbmgr", "queryn", sql)
end

function dbmgr.transaction(sqls)
    return skynet.call(__procname, "lua", "dbmgr", "transactionn", sqls)
end

function dbmgr.queryn(sql)
    local db = get_db()
    db.ref = db.ref + 1
    db.running = true
    db.time = skynet.time()
    local ok, result = skynet.call(db.handle, "lua", "db_service2", "query", sql)
    db.ref = db.ref - 1
    if db.ref <= 0 then
        db.ref, db.running = 0, false
    end
    return ok, result
end

function dbmgr.transactionn(sqls)
    local db = get_db()
    db.ref = db.ref + 1
    db.running = true
    db.time = skynet.time()
    local ok, result = skynet.call(db.handle, "lua", "db_service2", "transaction", sqls)
    db.ref = db.ref - 1
    if db.ref <= 0 then
        db.ref, db.running = 0, false
    end
    return ok, result
end

if SERVICE_NAME == "dbmgr" then
    
function dbmgr.init()
    skynet.dispatch("lua", skynet.dispatch_lua)
    skynet.register(__procname)
    for i = 1, 3 do
        local handle = skynet.newservice("db_service2")
        if handle then
            db_services[i] = {handle = handle, running = false, time = 0, ref = 0}
        end
    end
end




end




return dbmgr
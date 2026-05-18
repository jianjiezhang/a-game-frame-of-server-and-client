    


db_service2 = {}
local conn

function db_service2.query(sql)
    local ok, data = pcall(db_mysql.query, conn, sql)
    if not ok then
        skynet.error("db query failed:", sql, skynet.vardump(data))
    end
    return ok, data
end

function db_service2.transaction(sqls)
    local ok, err = db_service2.query("START TRANSACTION")
    if not ok then
        return ok, err
    end
    for _, sql in pairs(sqls) do
        local ok, err = db_service2.query(sql)
        if not ok then
            db_service2.query("ROLLBACK")
            return ok, err
        end
    end
    local ok, err = db_service2.query("COMMIT")
    if not ok then
        return ok, err
    end
    return true
end

if SERVICE_NAME == "db_service2" then

function db_service2.init()
    skynet.dispatch("lua", skynet.dispatch_lua)
    conn = db_mysql.connect("127.0.0.1", "root", "123456", "game", 3306)

    if not conn then
        skynet.error("connect failed")
        skynet.exit()
    end
    --local ok, result = db_service2.query("select * from t_item")
    --skynet.error("result:",skynet.vardump(result))
end

end









return db_service2

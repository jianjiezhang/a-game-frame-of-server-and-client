


local mysql = require "mysql"



db = {}

local function normalize_conf(name)
    if not name then
        return
    end
    return db_conf[name]
end

local function conf_table_name(conf)
    return conf[1]
end

local function conf_pk(conf)
    return conf[2]
end
local function conf_cols(conf)
    return conf[3]
end

local function build_col_index(conf)
    local cols = conf_cols(conf)
    local idx = {}
    for i = 1, #cols do
        local c = cols[i]
        local name = c[1]
        idx[name] = c
    end
    return idx
end

local function is_uint_type(typ)
    return string.sub(typ, 1, 4) == "uint"
end
local function is_blob(typ)
    return typ == "blob" or typ == "tinyblob" or typ == "mediumblob" or typ == "longblob"
end
local function parse_bits(typ)
    local n = string.match(typ or "", "^u?int(%d+)$")
    return n and tonumber(n) or nil
end
local function binary_len(typ)
   local n = string.match(typ or "binary(%d+)$")
   return n and tonumber(n) or nil
end
local function blob_len(typ)
    if typ == "tinyblob" then
        return (1<<8)-1
    elseif typ == "blob" then
        return (1<<16)-1
    elseif typ == "mediumblob" then
        return (1<<24)-1
    elseif typ == "longblob" then
        return (1<<32)-1
    end
end
local function is_string_type(typ)
    return string.match(typ, "^string%(%d+%)$") ~= nil
end
local function is_mixed_type(typ)
    return string.match(typ, "^mixed%(%d+%)$") ~= nil
end

local function serialize(value)
    local t = type(value)
    if t == "nil" then
        return "nil"
    elseif t == "number" then
        return tostring(value)
    elseif t == "boolean" then
        return tostring(value)
    elseif t == "string" then
        return string.format("%q", value)
    elseif t == "table" then
        local result = {}
        table.insert(result, "{")
        for k, v in pairs(value) do
            local key
            if type(k) == "string" and k:match("^[_%a][_%w]*$") then
                key = k
            else
                key = "[" .. serialize(k) .. "]"
            end
            table.insert(result, key .. "=" .. serialize(v) .. ",")
        end
        table.insert(result, "}")
        return table.concat(result)
    else
        error("unsupported type:" .. t)
    end
end
local function mixed_serialize(value)
    if type(value) ~= "table" then
        skynet.error("mixed serialize: value must be table:", skynet.vardump(value))
        return false
    end
    return serialize(value)
end


local function deserialize(str)
    local func, err = load("return " .. str)
    if not func then
        error("deserialize error:" .. err)
    end
    return func()
end
local function mixed_deserialize(str)
    if type(str) ~= "string" or string.sub(str, 1, 1) ~= "{" or string.sub(str, -1, -1) ~= "}" then
        skynet.error("mixed deserialize value must be string and start with { and end with }:", skynet.vardump(str))
        return false
    end
    return deserialize(str)
end

local function blob_pack(val)
    return skynet.packstring(val)
end
local function blob_unpack(str)
    return skynet.unpack(str)
end

local function maxlen_of(typ)
    local n = string.match(typ, "%((%d+)%)")
    return n and tonumber(n) or nil
end

local function check_int_range(v, bits, unsigned)    
    local iv = math.tointeger(v)
    if not iv then
        return true
    end

    if bits == 64 and unsigned then
        return iv >= 0 and iv <= (1<<63) - 1;        
    end
    if unsigned then
        local maxv = (1 << bits) - 1
        return iv >= 0 and iv <= maxv
    end
    local minv = -(1 << (bits - 1))
    local maxv = (1 << (bits - 1)) - 1
    return iv >= minv and iv <= maxv
end

local function is_badresult(res)
    if type(res) == "table" and res.badresult then
        return true
    end
    return false
end

local function quote_value(col_def, v)
    local typ = col_def and col_def[2]
    local default = col_def and col_def[3]

    if v == nil then
        skynet.error("value can not be nil value:", skynet.vardump(col_def))
        return false
    end

    if is_string_type(typ) then
        local ml = maxlen_of(typ)
        if type(v) ~= "string" then
            skynet.error("string expected but get:",type(v))
            return false
        end
        if ml and #v > ml then
            skynet.error("string length overflow for ", tostring(col_def[1]), " and max is ", ml)
            return false
        end
        return mysql.quote_sql_str(v)
    end

    if is_mixed_type(typ) then
        if type(v) ~= "table" then
            skynet.error("table expected but get:", type(v))
            return false
        end
        local ml = maxlen_of(typ)
        v = serialize(v)
        if ml and #v > ml then
            skynet.error("mixed serialize length overflow for ", tostring(col_def[1]), " and max is ", ml)
            return false
        end
        return mysql.quote_sql_str(v)
    end

--    if typ == "json" then
--        v = json.encode(v)
--        return mysql.quote_sql_str(v)
--    end

    local bits = parse_bits(typ)
    if bits then
        local unsigned = is_uint_type(typ)
        if type(v) ~= "number" then
            skynet.error("invalid number type for ", tostring(col_def[1]), " : ", type(v))
            return false
        end
        if not check_int_range(v, bits, unsigned) then
            skynet.error("number overflow for ", tosring(col_def[1]), ":", typ)
            return false
        end
        local iv = math.tointeger(v)
        return tostring(iv)
    end

    if typ == "float" then
        if type(v) ~= "number" then
            skynet.error("invalid float type:" , type(v))
            return false
        end
        return tostring(v)
    end
    if typ == "blob" or typ == "tinyblob" or typ == "mediumblob" or typ == "longblob" then
        local len = blob_len(typ)
        local iv = blob_pack(v)
        if len < #iv then
            skynet.error("blob is too big for ", col_def[1], ":", typ)
            return false
        end
        return mysql.quote_sql_str(iv)
    end
    return false
end

--local function decode_json(v)
--    if type(v) ~= "string" then
--        return v
--    end
--    return json.decode(v)
--end

local function cast_value(typ, v)
    if v == nil then
        return nil
    end
    local bits = parse_bits(typ)
    if bits or typ == "float" then
        return v
    end
    --if typ == "json" then
        --return decode_json(v)
    --end

    if is_mixed_type(typ) then
        return mixed_deserialize(v)
    end
    if is_blob(typ) then
        return blob_unpack(v)
    end
    return v
end

local function decode_rows(rows, conf, mode)
    local cols = conf_cols(conf)

    local function decode_row(r)
        local out = {}
        for i = 1, #cols do
            local col = cols[i]
            local name = col[1]
            out[name] = cast_value(col[2], r[name])
        end
        return out
    end

    local decoded = {}
    for i = 1, #rows do
        decoded[i] = decode_row(rows[i])
    end

    if mode == "row" then
        return decoded[1]
    end
    return decoded
end

local function apply_parse_conf(rows, parse_conf)
    if rows.multiresultset then --单句多结果
        local last = rows[#rows]
        last = apply_parse_conf(last, parse_conf)
        return last   
    end

    if rows.__multi then  --多句多结果
        local last = rows[#rows]
        last = apply_parse_conf(last, parse_conf)
        return last
    end

    local conf, mode = parse_conf.conf, parse_conf.mode
    return decode_rows(rows, conf, mode)
end


local function build_where_kv(colidx, ...)
    local n = select('#', ...)
    if n == 2 then
        local k, v = select(1, ...), select(2,...)
        local col = colidx[k]
        if not col then
            skynet.error("unnown column: ", tostring(k))
            return false
        end
        local value = quote_value(col, v)
        if not value then
            return false
        end
        return string.format("`%s`=%s", k, value)
    end
    if n%2 ~= 0 then
        skynet.error("key value pairs require")
        return false
    end
    local parts = {}
    for i = 1, n, 2 do
        local k, v = select(i, ...), select(i+1, ...)
        local col = colidx[k]
        if not col then
            skynet.error("unkown column: ", tostring(k))
        end
        local value = quote_value(col, v)
        if not value then
            return false
        end
        parts[#parts + 1] = string.format("`%s`=%s", k, value)
    end
    return table.concat(parts, " AND ")
end
local function build_where_reads(colidx, ...)
    local n = select ('#', ...)
    if n == 1 then
        local v = select(1, ...)
        if colidx.id then
            local value = quote_value(colidx.id, v)
            if not value then
                return false
            end
            return "role_id=" .. value
        end
        skynet.error("read(name, id) 需要在db_conf包含id字段")
        return false
    end
    return build_where_kv(colidx, ...)
end
local function build_where_read(colidx, ...)
    local n = select ('#', ...)
    if n == 1 then
        local v = select(1, ...)
        if colidx.id then
            local value = quote_value(colidx.id, v)
            if not value then
                return false
            end
            return "id=" .. value
        end
        skynet.error("read(name, id) 需要在db_conf包含id字段")
        return false
    end
    return build_where_kv(colidx, ...)
end


local function build_upsert_sql(conf, row)
    local tname = conf_table_name(conf)
    local cols = conf_cols(conf)
    local pk = conf_pk(conf)
    local pkset = {}
    for i = 1, #pk do
        pkset[pk[i]] = true
    end

    local names = {}
    local values = {}
    local updates = {}

    for i = 1, #cols do
        local col = cols[i]
        local name = col[1]
        names[#names + 1] = string.format("`%s`", name)
        local value = quote_value(col, row[name])
        if not value then
            return false
        end
        values[#values + 1] = value
        if not pkset[name] then
            updates[#updates+1] = string.format("`%s`=VALUES(`%s`)", name, name)
        end
    end

    return string.format(
        "INSERT INTO `%s` (%s) VALUES(%s) ON DUPLICATE KEY UPDATE %s",
        tname,
        table.concat(names, ","),
        table.concat(values, ","),
        table.concat(updates, ",")
    )
end
local function build_new_sql(conf, row)
    local tname = conf_table_name(conf)
    local cols = conf_cols(conf)
    local pk = conf_pk(conf)
    local pkset = {}
    for i = 1, #pk do
        pkset[pk[i]] = true
    end

    local names = {}
    local values = {}

    for i = 1, #cols do
        local col = cols[i]
        local name = col[1]
        names[#names + 1] = string.format("`%s`", name)
        local value = quote_value(col, row[name])
        if not value then
            return false
        end
        values[#values + 1] = value
    end

    return string.format(
        "INSERT INTO `%s` (%s) VALUES(%s)",
        tname,
        table.concat(names, ","),
        table.concat(values, ",")
    )
end
local function build_writes_sql(conf, partition_val, rows)
    local colidx = build_col_index(conf)
    local pk = conf_pk(conf)
    local tname = conf_table_name(conf)

    local partition_key = colidx.role_id and "role_id" or pk[1]
    if not partition_key then
        skynet.error("db writes require role_id or primary key")
        return false
    end
    local part_def = colidx[partition_key]
    local value = quote_value(part_def, partition_val)
    if not value then
        return false
    end
    local sqls = string.format("DELETE FROM `%s` WHERE `%s`=%s;",tname, partition_key, value)
    if #rows == 0 then
        return sqls
    end

    local cols = conf_cols(conf)
    local pkset = {}
    for i = 1, #pk do
        pkset[pk[i]] = true
    end

    local names = {}
    for i = 1, #cols do
        names[#names + 1] = string.format("`%s`", cols[i][1])
    end

    local values = {}
    for i = 1, #rows do
        local row = rows[i]
        local vs = {}
        for j = 1, #cols do
            local col = cols[j]
            local value = quote_value(col, row[col[1]])
            if not value then
                return false
            end
            vs[#vs + 1] = value
        end
        values[#values + 1] = "(" .. table.concat(vs, ",") .. ")"
    end

    local updates = {}
    for i = 1, #cols do
        local name = cols[i][1]
        if not pkset[name] then
            updates[#updates + 1] = string.format("`%s`=VALUES(`%s`)", name, name)
        end
    end

    sqls = sqls .. string.format(
        "INSERT INTO `%s` (%s) VALUES %s ON DUPLICATE KEY UPDATE %s;",
        tname,
        table.concat(names, ","),
        table.concat(values, ","),
        table.concat(updates, ",")
    )
    return sqls
end

--data:read succ, true:write succ,false:wirte and read falied
function db.execute(mysql_str, parse_conf)
    local res = db_service.query(mysql_str)
    if is_badresult(res) then
        skynet.error("res:",skynet.vardump(res))
        return false
    end
    if not parse_conf then
        return true
    end
    if type(parse_conf) == "string" then
        parse_conf = {conf = db_conf[parse_conf], mode = "rows"}
        return false
    end
    return apply_parse_conf(res, parse_conf)
end

function db.execute_atomic(mysql_str, parse_conf)
    local res = db_service.query_atomic(mysql_str)
    if is_badresult(res) then
        return false
    end
    if not parse_conf then
        return true
    end
    if type(parse_conf) == "string" then
        parse_conf = {conf = db_conf[parse_conf], mode = "rows"}
        return false
    end
    return apply_parse_conf(res, parse_conf)
end

function db.max(table, col)
    local sql = string.format("select max(`%s`) from %s", col, table)
    local res = db_service.query(sql)
    if is_badresult(res) then
        return false
    end
    local _, v = next(res[1])
    if not v then
        skynet.error("db.max failed:", skynet.vardump(_, v))
    end
    return v
end

function db.write_new(name, row)
    if not row or type(row) ~= "table" then
        skynet.error("partition_val or rows is wrong data:",skynet.vardump(name, row))
        return false
    end
    local conf = normalize_conf(name)
    if not conf then
        skynet.error("db_conf do not found for:", tostring(name))
        return false
    end
    local sql = build_new_sql(conf, row)
    if not sql then
        return false
    end
    return db.execute(sql)
end

function db.writes(name, partition_val, rows)
    if not partition_val or not rows or type(rows) ~= "table" then
        skynet.error("partition_val or rows is wrong data:",skynet.vardump(partition_val, rows))
        return false
    end
    local conf = normalize_conf(name)
    if not conf then
        skynet.error("db_conf not found for ", tostring(name))
        return false
    end
    local sqls = build_writes_sql(conf, partition_val, rows)
    if not sqls then
        return false
    end
    return db.execute_atomic(sqls)
end

function db.write(name, row)
    if not row or type(row) ~= "table" then
        skynet.error("partition_val or rows is wrong data:",skynet.vardump(name, row))
        return false
    end
    local conf = normalize_conf(name)
    if not conf then
        skynet.error("db_conf do not found for:", tostring(name))
        return false
    end
    local sql = build_upsert_sql(conf, row)
    if not sql then
        return false
    end
    return db.execute(sql)
end

function db.reads(name, ...)
    local conf = normalize_conf(name)
    if not conf then
        skynet.error("db_conf do not found ", name)
        return false
    end
    local tname = conf_table_name(conf)
    local colidx = build_col_index(conf)
    local where = build_where_reads(colidx, ...)
    if not tname or not colidx or not where then
        return false
    end
    local sql = string.format("select * from `%s` where %s", tname, where)
    return db.execute(sql, {conf = conf, mode = "rows"})
end

function db.read(name, ...)
    local conf = normalize_conf(name)
    if not conf then
        skynet.error("db_conf do not found ", name)
        return false
    end
    local tname = conf_table_name(conf)
    local colidx = build_col_index(conf)
    local where = build_where_read(colidx, ...)
    if not tname or not colidx or not where then
        return false
    end
    local sql = string.format("select * from `%s` where %s limit 1", tname, where)
    return db.execute(sql, {conf = conf, mode = "row"})
end

function db.new(name, ...)
    local conf = normalize_conf(name)
    if not conf then
        skynet.error("db_conf not found for ", tostring(name))
        return false
    end
    local result = {}
    local cols = conf_cols(conf)
    for _, v in pairs(cols) do
        result[v[1]] = v[3]
    end

    local n = select('#', ...)
    if n %2 ~= 0 then
        skynet.error("key value pairs is not fixed...")
        return false
    end
    if n~= 0 then
        for i = 1, n, 2 do
            local k, v = select(i, ...), select(i + 1, ...)
            result[k] = v
        end
    end
    return result
end

return db









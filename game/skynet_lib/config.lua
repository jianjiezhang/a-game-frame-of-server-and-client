

config = {}

local function resolve_entry(name)
    local path = string.gsub("./conf/?.lua", "?", name)
    return name, path
end

local function load_one(name)
    local data_name, file_path = resolve_entry(name)
    sharedata.update(data_name, "@" .. file_path)
    return data_name
end

local function init_array_item(item)
    return load_one(item)
end

function config.load(name)
    return load_one(name)
end

function config.get(name)
    return sharedata.query(name)
end

function config.copy(name, ...)
    return sharedata.deepcopy(name, ...)
end

function config.reload(name)
    return load_one(name)
end

function config.loads(names)
    for _, v in pairs(names) do
        load_one(v)
    end
end

function config.init()
    local names = {}
    local p = io.popen("find ./conf/ -type f")
    for file in p:lines() do
        names[#names+1] = file
    end
    p:close()
    for k, v in pairs(names) do
        names[k] = string.match(v, "./conf/(.*).lua")
    end

    local loaded = {}
    for _, item in ipairs(names) do
        loaded[#loaded+1] = init_array_item(item)
    end
    return loaded
end





return config
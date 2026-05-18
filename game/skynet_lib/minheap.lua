

minheap = {}

minheap.__index = minheap

local function get_index(obj, func, args)
    local ftab = obj.index[func]
    if not ftab then
        return
    end
    if not args then
        return ftab
    end
    return ftab[args]
end
local function set_index(obj, func, args, idx)
    local ftab = obj.index[func]
    if not ftab then
        ftab = {}
        obj.index[func] = ftab
    end
    if not args then
        obj.index[func] = idx
        return
    end
    ftab[args] = idx
end
local function clear_index(obj, func, args)
    local ftab = obj.index[func]
    if not ftab then
        return
    end
    if not args then
        obj.index[func] = nil
        return
    end
    ftab[args] = nil
    if next(ftab) == nil then
        obj.index[func] = nil
    end
end



local function swap(obj, i, j)
    local nodes = obj.nodes
    nodes[i], nodes[j] = nodes[j], nodes[i]

    local a, b = nodes[i], nodes[j]
    set_index(obj, a.func, a.args, i)
    set_index(obj, b.func, b.args, j)
end

local function shift_up(obj, i)
    while(i > 1) do
        local parent = math.floor(i/2)
        if obj.cmp(obj.nodes[parent], obj.nodes[i]) then
            break
        end
        swap(obj, parent, i)
        i = parent
    end
end

local function shift_down(obj, i)
    local size = #obj.nodes

    while true do
        local left = i *2
        local right = left + 1
        local smallest = i

        if left <= size and not obj.cmp(obj.nodes[smallest].value, obj.nodes[left].value) then
            smallest = left
        end
        if right <= size and not obj.cmp(obj.nodes[smallest].value, obj.nodes[right].value) then
            smallest = right
        end

        if smallest == i then
            break
        end
        swap(self, i, smallest)
        i = smallest
    end
end
--=========================public========================
function minheap:new(cmp)
    if type(cmp) ~= "function" then
        skynet.error("cmp function required")
        return false
    end
    local obj = {
        nodes = {},
        index = {},
        cmp = cmp
    }
    setmetatable(obj, minheap)
    return obj
end

function minheap:push(func, args, value)
    local idx = get_index(self, func, args)
    if idx then
        self:update(func, args, value)
        return
    end

    local node = {func = func, args = args, value = value}

    table.insert(self.nodes, node)
    local new_idx = #self.nodes

    set_index(self, func, args, new_idx)
    shift_up(self, new_idx)
end

function minheap:update(func, args, value)
    local idx = get_index(self, func, args)
    if not idx then
        return false
    end

    self.nodes[idx].value = value
    shift_up(self, idx)
    shift_down(self, idx)

    return true
end

function minheap:remove(func, args)
    local idx = get_index(self, func, args)
    if not idx then
        return
    end

    local last = #self.nodes
    if last ~= idx then
        swap(self, idx, last)
    end
    local removed = table.remove(self.nodes)
    clear_index(self, removed.func, removed.args)

    if idx <= #self.nodes then
        shift_up(self, idx)
        shift_down(self, idx)
    end
    return true
end

function minheap:pop()
    if #self.nodes == 0 then
        return
    end

    local root = self.nodes[1]
    self:remove(root.func, root.args)

    return root.func, root.args, root.value
end

function minheap:peek()
    local root = self.nodes[1]
    if not root then
        return
    end
    return root.func, root.args, root.value
end

function minheap:size()
    return #self.nodes
end




return minheap
















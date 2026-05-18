require "minheap"

timer = {}
local __timers


function timer.cmp(e1, e2)
    return e1.value < e2.value
end
function timer.init()
    __timers = minheap:new(timer.cmp)
end
function timer.loop()
    local now = os.time()
    while(true) do
        local root_func, root_args, root_time = __timers:peek()
        if not root_time or root_time > now then
            break
        end
        __timers:pop()
        root_func(root_args)
    end
end
function timer.dispatch()
    if not __timers then
        return
    end
    local now = os.time()
    local _, _, root_time = __timers:peek()
    if not root_time or root_time > now then
        return
    end
    local ok, err = pcall(timer.loop, debug.traceback)
    if not ok then
        printf("timer loop err:", tostring(err))
    end
end

function timer.push_ends(func, ends, args)
    __timers:push(func, args, ends)
end
function timer.remove(func, args)
    __timers:remove(func, args)
end
function timer.get()
    return __timers
end









return timer

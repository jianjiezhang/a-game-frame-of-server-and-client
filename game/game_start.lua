



local handle = skynet.launch("snlua", "launcher")
if not handle then
    skynet.error("启动器启动失败...")
else
    skynet.name(".launcher", handle)
end
skynet.send(".launcher", "lua" , "LAUNCH", "snlua", "game")



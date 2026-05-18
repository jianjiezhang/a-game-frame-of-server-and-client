-- Net.lua：网络字节流由 C# Net 线程收发；全局函数 send_to_server(id, data) 由 Main.cs 在创建虚拟机后注入。
-- 业务侧使用 Proto.pack / send_to_server，与 game/client/client2.lua 约定一致。

return {}


game = {}

local __procname = ".game"
skynet.register(__procname)

function game.send_start()
	game.send("game","start")
end
function game.send(...)
	skynet.send(__procname, "system", ...)
end

function game.start()
	skynet.dispatch("lua", skynet.dispatch_lua)
	skynet.error("开始启动游戏服务器,编号,服务器id....")
	--服务启动
	local launch_handle = skynet.launch("snlua", "launcher") 
	if not launch_handle then
		skynet.error("启动器启动失败...")
	else
		skynet.name(".launcher", launch_handle)
	end
	
	--配置
	skynet.setvenv("intvl", tostring(0))
	--管理服务
	skynet.newservice("gatemgr")
	skynet.newservice("consolemgr") --debug窗口支持
	skynet.newservice("sharedatad")

	--游戏配置
	config.init()
	--游戏服务
	--游戏服务管理器
	--缓存服务管理
	--在线管理
	--社交
	--聊天
	--场景管理
	skynet.newservice("scenemgr")
	--战斗
	--匹配
	--配置管理
	--活动
	--联盟
	--集群

	--网络管理
	--skynet.newservice("watchdog")
	--if not skynet.newservice("watchdog") then
	--	skynet.error("网络管理启动失败")
	--end

	skynet.newservice("db_service")
	--skynet.newservice("dbmgr")
	collectgarbage("collect")
	--skynet.sleep(300)
	skynet.error("启动服务器成功")
end

function game.save()

end

function game.stop()

end

function game.hotup()

end
if SERVICE_NAME == "game" then
	function game.init()
		game.start()
	end
end


return game

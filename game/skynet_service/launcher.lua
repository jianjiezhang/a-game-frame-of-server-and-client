local core = require "skynet.core"
	-- import manager apis
launcher = {}

local services = {}
local instance = {} -- for confirm (function launcher.LAUNCH / launcher.ERROR / launcher.LAUNCHOK)
local launch_session = {} -- for launcher.QUERY, service_address -> session
local function handle_to_address(handle)
	return tonumber("0x" .. string.sub(handle , 2))
end

local NORET = {}

function launcher.LIST()
	local list = {}
	for k,v in pairs(services) do
		list[skynet.address(k)] = v
	end
	return list
end

local function list_srv(ti, fmt_func, ...)
	local list = {}
	local sessions = {}
	local req = skynet.request()
	for addr in pairs(services) do
		local r = { addr, "debug", ... }
		req:add(r)
		sessions[r] = addr
	end
	for req, resp in req:select(ti) do
		local addr = req[1]
		if resp then
			local stat = resp[1]
			list[skynet.address(addr)] = fmt_func(stat, addr)
		else
			list[skynet.address(addr)] = fmt_func("ERROR", addr)
		end
		sessions[req] = nil
	end
	for session, addr in pairs(sessions) do
		list[skynet.address(addr)] = fmt_func("TIMEOUT", addr)
	end
	return list
end

function launcher.STAT(addr, ti)
	return list_srv(ti, function(v) return v end, "STAT")
end

function launcher.KILL(handle)
	skynet.kill(handle)
	local ret = { [skynet.address(handle)] = tostring(services[handle]) }
	services[handle] = nil
	return ret
end

function launcher.MEM(addr, ti)
	return list_srv(ti, function(kb, addr)
		local v = services[addr]
		if type(kb) == "string" then
			return string.format("%s (%s)", kb, v)
		else
			return string.format("%.2f Kb (%s)",kb,v)
		end
	end, "MEM")
end

function launcher.GC(addr, ti)
	for k,v in pairs(services) do
		skynet.send(k,"debug","GC")
	end
	return launcher.MEM(addr, ti)
end

function launcher.REMOVE(handle, kill)
	services[handle] = nil
	local response = instance[handle]
	if response then
		-- instance is dead
		response(not kill)	-- return nil to caller of newservice, when kill == false
		instance[handle] = nil
		launch_session[handle] = nil
	end
end

local function launch_service(service, name, ...)
	local inst = skynet.launch(service, name)
	local session = skynet.context()
	local response = skynet.response()
	if inst then
		services[inst] = service .. " " .. name
		instance[inst] = response
		launch_session[inst] = session
		skynet.send(inst, "system", "skynet", "init", ...)
	else
		response(false)
		return
	end
	return inst
end

function launcher.LAUNCH(service, ...)
	launch_service(service, ...)
end

function launcher.LOGLAUNCH(service, ...)
	local inst = launch_service(service, ...)
	if inst then
		core.command("LOGON", skynet.address(inst))
	end
end

function launcher.ERROR(address)
	-- see serivce-src/service_lua.c
	-- init failed
	local response = instance[address]
	if response then
		response(false)
		launch_session[address] = nil
		instance[address] = nil
	end
	services[address] = nil
end

function launcher.LAUNCHOK(address)
	-- init notice
	local response = instance[address]
	if response then
		response(true, address)
		instance[address] = nil
		launch_session[address] = nil
	end
end

function launcher.QUERY(request_session)
	for address, session in pairs(launch_session) do
		if session == request_session then
			return address
		end
	end
end

-- for historical reasons, launcher support text launcher (for C service)
if SERVICE_NAME == "launcher" then

skynet.register_protocol {
	name = "text",
	id = skynet.PTYPE_TEXT,
	unpack = skynet.tostring,
	dispatch = function(session, address , cmd)
		if cmd == "" then
			launcher.LAUNCHOK(address)
		elseif cmd == "ERROR" then
			launcher.ERROR(address)
		else
			error ("Invalid text command " .. cmd)
		end
	end,
}
skynet.dispatch("lua", skynet.dispatch_lua, launcher)


end

return launcher

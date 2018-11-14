local skynet = require "skynet"
require "utils.functions"
local logger = require "logger"
local json = require "json"
require "skynet.manager"

local serveraddr = skynet.getenv("serveraddr")
local start_interval = tonumber(skynet.getenv("start_interval")) or 10
local test_opt = skynet.getenv("test_opt")
local clients = {}
assert(serveraddr, "serveraddr should not be nil")


local user_params = {} --备份某个机器人id与其对应的参数,在重新恢复时用


local function new_client(i, handler, param)
	return skynet.newservice("client_agent", i, serveraddr, handler, param)
end

local function get_client_stat(clients)
	local alive_clients = {}
	local dead_clients = {}

	for k, v in pairs(clients) do
		local ok = skynet.send(v, "debug", "GC")
		if ok then
			table.insert(alive_clients, k)
		else
			table.insert(dead_clients, k)
		end
	end
	return alive_clients, dead_clients
end

local function main()
	assert(test_opt)
    local opt = require (test_opt)

    assert(opt)
    for _, item in pairs(opt) do
        for i = item["startid"], item["endid"] do
            local param = item["param"] or {}
            local test_handler = item["handler"]
            user_params[i] = {param = param, handler = test_handler}
            clients[i] = new_client(i, test_handler, json.encode(param))
            skynet.sleep(start_interval)
        end
    end

	while true do
		local _, dead_clients = get_client_stat(clients)
        if #dead_clients > 0 then
            logger.info("dead_clients count = %s", #dead_clients)
        end
		for _, i in ipairs(dead_clients) do
			logger.info("restart dead client: %s", i)
            local param = user_params[i].param
            local handler = user_params[i].handler
            assert(param)
            assert(handler)
			clients[i] = new_client(i, handler, json.encode(param))
			skynet.sleep(start_interval)
		end
		skynet.sleep(30*100)
	end
end

skynet.start(function ()
	skynet.dispatch("lua", function(session, source, cmd, ...)
		local f = CMD[cmd]
		if not f then
			error(string.format("Unknown command %s, source:%s", cmd, source))
		end
		if session == 0 then
			f(...)
		else
			skynet.ret(skynet.pack(f(...)))
		end
	end)
	skynet.info_func(function ( ... )
		return {}
	end)
	skynet.fork(main)
	skynet.register ".test_many_client"
end)

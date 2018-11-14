local skynet = require "skynet"
require "skynet.manager"
local client = require "client"
local logger = require "logger"
local json = require "json"

local id, svaddr, handler, param = ...
assert(id)
assert(svaddr)
assert(handler)
assert(param)
local param = json.decode(param)
local client_handler = require(handler)
local test_item = skynet.getenv("test_item")
local is_encrypt = tonumber(skynet.getenv("is_encrypt")) or 0
is_encrypt = is_encrypt ~= 0 and true or false
local key_secret = skynet.getenv("key_secret")


local function start()
	-- open client
	local cl = client.open(svaddr, function (...) return client_handler:on_request(...), true end, 
		is_encrypt, key_secret, id)
	if not cl then 
		logger.warn("open client fail, id = %s", id)
		return skynet.exit() 
	end
	client_handler:main(id, cl, param)
	return true
end


skynet.start(function ()
	skynet.fork(start)

	skynet.fork(function()
		while true do
			skynet.sleep(15*100)
			skynet.send(skynet.self(), "debug", "GC")
		end
	end)
end)


local skynet = require "skynet"
local service = nil
local pubsub = {}
local mt = {}
mt.__index = function(t, k) 
	local f = function(self, ...)
		return skynet.call(service, 'lua', 'command', k, ...) 
	end
	return f
end
setmetatable(pubsub, mt)

function pubsub.sub(channel, hook)
	if not service then return false end
	return pcall(skynet.call, service, 'lua', 'sub', channel, skynet.self(), hook)
end

function pubsub.pub(channel, msg)
	if not service then return false end
	return pcall(skynet.call, service, 'lua', 'pub', channel, msg)
end

skynet.init(function()
	service = skynet.uniqueservice('redis_pubsub')	
end)

return pubsub

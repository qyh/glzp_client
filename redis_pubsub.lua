local skynet = require "skynet"
local redis = require "redis"
local server_config = require "glzp.server_config"
local logger = require "logger"
local futil = require "futil"
local const = require "const"
require "glzp.tostring"
require "skynet.manager"
local redis_config = server_config['redisConfig']
local CMD = {}
local db = nil

local channels = {}

function CMD.pub(channel, msg)
	if not channel then
		return false
	end
	if db then
		db:publish(channel, msg)
		return true
	end
	return false
end

function CMD.command(cmd, ...)
	if db then
		local f = db[cmd]
		if f then
			return f(db, ...)
		end
	end
	return nil
end

function CMD.sub(channel, service, hook)
	if not (channel and service and hook) then
		logger.err('redis_pubsub failed:%s,%s,%s',channel, service, hook)
		return false
	end
	if not const.pubsubChannel[channel] then
		logger.err('sub,unknown channel %s', tostring(channel))
		return false
	end
	logger.debug('redis_pubsub recv sub:%s,%s,%s',channel, service, hook)
	local ch = channels[channel] or {}
	ch[service] = hook
	channels[channel] = ch
	return true
end

function CMD.unsub(channel, service)
	if not const.pubsubChannel[channel] then
		logger.err('unsub,unknown channel %s', tostring(channel))
		return false
	end
	local ch = channels[channel] 
	if ch then
		ch[service] = nil
	end
end

skynet.init(function()
	local w = redis.watch(redis_config)
	if w then
		for k, v in pairs(const.pubsubChannel) do
			w:subscribe(k)
		end
		skynet.fork(function()
			while true do
				local msg, ch = w:message()
				local channel = channels[ch] 
				if channel then
					for service, hook in pairs(channel) do
						pcall(skynet.send, service, 'lua', hook, ch, msg)
					end
				end
			end
		end)
	else
		logger.err('redis.watch failed:%s', table.tostring(redis_config))
	end
end)

skynet.start(function()
	skynet.dispatch('lua', function(session, address, cmd, ...)
		local f = CMD[cmd]
		if f then
			if session > 0 then
				skynet.ret(skynet.pack(f(...)))
			else
				f(...)
			end
		else
			logger.err('ERROR: Unknown command:%s', tostring(cmd))
		end
	end)
	db = redis.connect(redis_config)
	if db then
		logger.debug('redis connect success')
	else
		logger.err('redis connect failed:%s', table.tostring(redis_config))
	end
    skynet.register(".redis_pubsub")
end)


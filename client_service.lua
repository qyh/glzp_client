local skynet = require "skynet"
require "utils.functions"
local logger = require "logger"
local json = require "cjson"
require "skynet.manager"
local futil = require "utils.futil"
local redis = require "pubsub"
local const = require "const"

local test_opt = skynet.getenv("test_opt")
local client_mgr = nil
local conf = {}
local CMD = {}
local inGame = {}
local signal = nil
local function start(test_opt)
	if client_mgr then
		logger.err('client manager is running, try stop first!!!')
		return false
	end
	client_mgr = skynet.newservice("client_manager")
	if client_mgr then
		skynet.call(client_mgr, 'lua', 'start', test_opt)
		logger.info('client manager start success !')
		return true
	else
		logger.err('client manager start failed !')
		return false
	end
end

local function stop()
	if client_mgr then
		logger.info('stop client manager...')
		skynet.call(client_mgr, 'lua', 'stop')
		skynet.kill(client_mgr)
		logger.err('kill client manager success')
		client_mgr = nil
	end
end

local function init()
	local rconf = redis:get('client_service_conf')
	if not rconf then
		local opt = require(test_opt)
		local tmpConf = {}
		tmpConf.option= opt
		local curTime = os.time()
		local endTime = curTime + 10*24*3600
		tmpConf.startTime = futil.nowstr(curTime)
		tmpConf.endTime = futil.nowstr(endTime)
		logger.debug('set client_service_conf:%s', futil.toStr(tmpConf))
		redis:set('client_service_conf', json.encode(tmpConf))
		conf = tmpConf
	else
		logger.debug('get client_service_conf:%s', rconf)
		local tmpConf = json.decode(rconf)
		if not (tmpConf and next(tmpConf)) then
			logger.err('config not found or empty:%s', tmpConf)
			return false
		end
		if not (tmpConf.option and next(tmpConf.option)) then
			logger.err('config option nil')
			return false
		end
		-- set default handler
		if not tmpConf.handler then
			tmpConf.handler = "challenge_handler"
		end
		for k, info in pairs(tmpConf.option) do
			tmpConf.option[k] = math.tointeger(info) or info
			info.handler = tmpConf.handler
			for i, v in pairs(info) do
				info[i] = math.tointeger(v) or v 
			end
		end
		conf = tmpConf
		logger.debug('config:%s', futil.toStr(conf))
	end
	return true
end

local function run()
	while true do
		local curTime = os.time()
		if conf and next(conf) and signal ~= 'stop' then
			if futil.getTimeByDate(conf.startTime) <= curTime 
				and futil.getTimeByDate(conf.endTime) > curTime then
				if not client_mgr then
					start(conf.option)
				end
			else
				if client_mgr then
					stop()
				end
			end
		end
		local status = 'running'
		if not client_mgr then
			status = 'stop'
		end
		redis:setex('client_service_status', 5, status)
		skynet.sleep(300)
	end
end

function CMD.pubsub(channel, msg)
	logger.debug('recv channel:%s, msg:%s', channel, msg)
	if channel ~= 'client_service' then
		return
	end
	if msg == 'start' then
		signal = msg
		init()
	elseif msg == 'stop' then
		signal = msg
		stop()
	elseif msg == 'restart' then
		signal = msg
		stop()
		init()
	end
end
function CMD.gaming(id, flag)
	inGame[id] = flag
	local playCount = 0
	local notPlayCount = 0
	for k, v in pairs(inGame) do
		if v == true then
			playCount = playCount + 1
		else
			notPlayCount = notPlayCount + 1
		end
	end
	
	logger.warn('playing count:%s, not playing count:%s', 
		playCount, notPlayCount)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
		local f = CMD[cmd]
		if not f then
			logger.err('unkonwn command:%s', cmd)
		end
		if session == 0 then
			f(...)
		else
			skynet.ret(skynet.pack(f(...)))
		end
	end)
	init()
	skynet.fork(run)
	skynet.register(".client_service")
	redis.sub(const.pubsubChannel.client_service, 'pubsub')
end)


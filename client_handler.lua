local skynet = require "skynet"
local logger = require "logger"
local json = require "json"
require "utils.tostring"
require "utils.functions"
local futil = require "utils.futil"
local ct = require "glzp.common_lib"
local h = require "glzp.head_file"
local hs = require "glzp.headfile_server"

local appver = skynet.getenv("appver") or "1.1.4.0"
local login_channel = skynet.getenv("login_channel") or "LKLoadTest"

local const
local handler = {__request = {}, ctx = {}}

local function response_function(ctx)
	if ctx then ctx.co = coroutine.running() end
	return function (resp)
		if not ctx or not ctx.co then return end
		ctx.resp = resp
		skynet.wakeup(ctx.co)
		ctx.co = nil
	end
end

function handler:gm(cmd)
	local resp = self:request("gm", {cmd = cmd})
	if (resp and resp.ok) then
		return true
	end
	logger.warn("gm fail, id = %s, cmd = %s, resp = %s", self.id, cmd, table.tostring(resp))
	return false
end


function handler:check_error_code(reqname, resp, expect_error_code)
	if not (resp and (resp.error_code == expect_error_code or resp.errorCode == expect_error_code)) then
		logger.err("%s fail, id = %s, resp = %s, will exit", reqname, self.id, table.tostring(resp))
		return skynet.exit()
	end
end

local function heartbeat(self)
	while true do
		if self.cl:closed() then
			break
		end
		local hdata = {userID=self.auth.userInfo_.userID} 
		--logger.info('heartbeat data:%s,%s', futil.toStr(hdata), self)
		self:request(h.enumEndPoint.LOBBY_SERVER, 0, h.enumKeyAction.HEARTBEAT, 'heartbeatReply', hdata)	
		skynet.sleep(const.heartbeat.send_interval * 100)
	end
end

function handler:login(param)
	local cl = self.cl
	local openid = string.format("robot%s", self.id)
	local password = '123456'

	if param.account then
		openid = param.account
	end
	if param.password then
		password = param.password
	end
	local data = {
		userName = openid,
		thirdToken = password,
		thirdPlatformID = h.thirdPlatformID.Zipai,
		version = param.appver or "0.0.0.0",
		deviceID = h.deviceID.PC,
		extraData = nil,
		timestamp = os.time(),
		spreader = "",
		newSpreader = "",
	}	
	local r = self:request(h.enumEndPoint.LOGIN_SERVER, 0, h.enumKeyAction.AUTH, 'auth', data)
	if r and r.authResult == 0 then
		self.auth = r
		skynet.fork(heartbeat, self)
		logger.info("login finish, id = %s", self.id)
	else
		logger.err('login timeout')
		skynet.exit()
	end
end



function handler:exit()
	self.cl:close()
    logger.info("client exit, id = %s", self.id)
	return skynet.exit()
end

function handler:request(dst, module, action, name, args, nonblock)
	assert(type(name)=='string')
	local cl = self.cl
	if nonblock then return cl:request(dst, module, action, name, args) end
	local ctx = {}
	local ok = cl:request(dst, module, action, name, args, response_function(ctx))
	if not ok then
		logger.info("client %s request %s fail, will exit", self.id, name)
		ctx.co = nil
		return false
	end
	-- break after 30 sec no response from server
	local co = coroutine.running()
	skynet.timeout(3000, function()
		if ctx.co then
			ctx.co = nil
			skynet.wakeup(co)
		end
	end)
	skynet.wait()
	return ctx.resp
end

function handler:on_request(name, args, response)
	local f = self.__request[name]
	local r
	if f then 
		local ok, res = xpcall(f, futil.handle_error, self, args)
		if not ok then
			logger.err('%s', tostring(res))
		else
			r = res --f(self, args) 
		end
	end
	if not response then return end
	return response(r)
end

function handler:main(id, cl, param)
	self.id = id
	self.cl = cl
	self.param = param
	-- setup request handler
	self:setup(param)
	-- login
	logger.info('begin login...')
	self:login(param)
	logger.info('login end')
	-- select mode
	-- run test
	self:run()
end

function handler:setup()
end

function handler:login_in_queue(args)
    logger.warn("robot_%s login_in_queue %s", self.id, args.wait_seconds)
end

function handler:run()
	-- start mainloop
	math.randomseed(os.time()+os.clock()*1000000)
	while not self.cl:closed() do
		-- do something
		skynet.sleep(math.random(50, 100))
		logger.info("++++ hahaha")
	end
end

skynet.init(function()
	const = require "const"
end)
return handler


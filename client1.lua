--package.cpath = "../../luaclib/?.so;../../cservice/?.so;"
--package.path = "lualib/?.lua;../gamesvr/?.lua;../common/?.lua"
package.path = "./lualib/?.lua;./bin/test/?.lua"


if _VERSION ~= "Lua 5.3" then
	error "Use lua 5.3"
end

require "utils.functions"

local socket = require "clientsocket"
local proto = require "glzp.proto"
local sproto = require "sproto"
local print_r = require "utils.print_r"
local json = require "json"
local skynet = require "skynet"
local ct = require "glzp.common_lib"
local h = require "glzp.head_file"
local hs = require "glzp.headfile_server"
local crypt=require "crypt" 
-- local json = require "json"

local host 
local request 

--local fd = assert(socket.connect("127.0.0.1", 8888))

local fd = assert(socket.connect("127.0.0.1", 8888))
print('connect fd:', fd)
local user_name = "robot_1"
local classic_cell = {}
local Response = {}
local current_time = 0


local function send_package(fd, pack, dst, module, action)
	local msg,msgHead = ct.loadMsgHead(
		pack,
		h.enumEndPoint.CLIENT,
		dst,
		module,
		action
	)
	--[[
	if h.encodeFlag == true then
	    msg=crypt.aesencode(msg,hs.passwd,"")
	end	
	]]
	print('send_package:', msgHead.msgTag)
	local package = string.pack(">s2", msg)
	local r = socket.send(fd, package)
	print('send_pack:', r)
end

local function unpack_package(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, text
	end

	return text:sub(3,2+s), text:sub(3+s)
end

local function recv_package(last)
	local result
	result, last = unpack_package(last)
	if result then
		return result, last
	end
	local r = socket.recv(fd)
	if not r then
		return nil, last
	end
	if r == "" then
		error "Server closed"
	end
	return unpack_package(last .. r)
end

local session = 0


local session = 0
local req_names = {}

local function send_request(name, args)
	session = session + 1
	local str = request(name, args, session)
	print('send_request..')
	print('xxx',h.enumEndPoint.LOGIN_SERVER,h.enumKeyAction.AUTH)
	send_package(fd, str, h.enumEndPoint.LOGIN_SERVER, 0, h.enumKeyAction.AUTH)
	req_names[session] = name
	return session
end

-- response callback
function Response.login_openid2(args)
	print('-------')
	print_r(args)
	print('-------')

	if args.errorCode ~= 0 then
		error("login error")
	end

	uid = args.accountInfo.uid
end

local schedulers = {}

function schedule(callback, t, repeated)
	table.insert(schedulers, {callback=callback, t=current_time+t, interval=t, repeated=repeated})
end



local last = ""

local function print_request(name, args)
	if name == "heartbeat" then
		heart_beat_session = send_request('heartbeat')
		return
	end
end

local function print_response(session, args)
	print("RESPONSE", session)
	if args then
		for k,v in pairs(args) do
			print(k,v)
		end
	end
end

local function print_package(t, ...)
	if t == "REQUEST" then
		print_request(...)
	else
		assert(t == "RESPONSE")
		print_response(...)
	end
end

local function onResponse(session, args)
	local reqName = req_names[session]
	local f = Response[reqName]
	if f then
		f(args)
		return 
	end

	print("<====RESPONSE session="..session)
	if args then
		print_r(args)
	end
end

local function onMessage(t, ...)
	if t == "REQUEST" then
		print_request(...)
	else
		assert(t == "RESPONSE")
		onResponse(...)
	end
end

local function dispatch_package()
	while true do
		local v
		v, last = recv_package(last)
		if not v then
			break
		end

		onMessage(host:dispatch(v))
	end
end

--send_request("handshake")
print('---------')
-- 向登陆服务器发送登陆请求, 获取游戏服务器列表
host = sproto.new(proto.s2c):host "package"
request = host:attach(sproto.new(proto.c2s))
--[[
local pi = {SystemSoftware = "ss", SystemHardware ="sh", TelecomOper ="to", 
			Network ="nw", ScreenWidth = 100, ScreenHight = 200, Density = 3.1415, 
			LoginChannel = "lkgod", CpuHardware = "ch", Memory = 2048, 
			GLRender = "1.0", GLVersion = "2.0", DeviceId = "3.0"}
local spi = json.encode(pi)
send_request('login_openid2', {accountPlatform = 'lk', phonePlatform = 1, 
	openid = user_name, token = "123456", version = "1.0.0.100", phoneInfo = spi})
]]

while true do
	for k, v in pairs(schedulers) do
		if current_time > v.t then
			v.callback()
			if not v.repeated then
				schedulers[k] = nil
			else
				v.t = current_time + v.interval
			end
		end
	end
	dispatch_package()
	local text = socket.readstdin()
	local t = string.split(text, " ")
	cmd = t[1]
	args = {}
	if #t > 1 then
		for i = 2, #t do
			args[i-1] = t[i]
		end
	end
	-- 精度微秒
	socket.usleep(100000)
	current_time = current_time + 0.1
end
print('xxxxxxxxxx', skynet.error)
skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		
	end)
	print('print start ..')
	skynet.fork(function()
		local data = {
			userName = 'robot1',
			thirdToken = '123456',
			thirdPlatformID = h.thirdPlatformID.Zipai,
			version = "0.0.0.0",
			deviceID  = h.deviceID.PC,
			extraData = nil,
			timestamp = os.time(),
			spreader  = "",
			newSpreader = "",
		}
		send_request('auth', data)
	end)
	skynet.error('client start ...')
end)




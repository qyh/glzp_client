local skynet = require "skynet"
local crypt = require "crypt"
local logger = require "logger"
local md5 = require "md5"
local socketdriver = require "socketdriver"
local sproto = require "sproto"
local proto = require "proto"
local ok, socket = pcall(require, "socket")
local futil = require "futil"
local ct = require "common_lib"
local h = require "head_file"
local hs = require "headfile_server"

local const require "const"
local host = sproto.new(proto.s2c):host "package"
local request = host:attach(sproto.new(proto.c2s))

local client = {}
client.__index = client

local function raw_recv_package(sock)
	local header_data = socket.read(sock, 2)
	if not header_data then
		error("recv no header data, maybe disconnect")
	end
	local sz = socket.header(header_data)
	return socket.read(sock, sz)
	--[[
	local r, istimeout = socket.recv(sock, 1000*1000*30)
	if not r then
		return nil
	end
	if r == "" and istimeout == 0 then
		logger.err('Server Closed')
		return nil
	end
	return r
	]]
end

local function recv_package(self)
	local data = raw_recv_package(self.__sock)
	self.__last_heartbeat_time = os.time()
	if not data then return end
	if self.__token then
		data = crypt.desdecode(self.__token, data)
	end
	return data
end

local function raw_send_package(sock, data)
	local size = #data
	local package = string.pack(">s2", data)
	return socket.write(sock, package)
	--[[
	return socket.send(sock, data)
	]]
end

local function send_package(self, data)
	self.__last_send_time = os.time()
	if self.__token then
		return raw_send_package(self.__sock, crypt.desencode(self.__token, data))
	else
		return raw_send_package(self.__sock, data)
	end
end

local function response_function(self, response)
	if not response then return end
	return function (result)
		return send_package(self, response(result))
	end
end

local function check_heartbeat(self)
	while not self.__closed do
        skynet.sleep(const.heartbeat.timeout)
        if (os.time() - self.__last_heartbeat_time) > const.heartbeat.timeout then
            logger.warn("svr heartbeat timeout, will exit")
            self:close("svr heartbeat timeout")
            skynet.exit()
        end
    end
end

local function heartbeat(self)
	while not self.__closed do
		local intv = const.heartbeat.send_interval - (os.time() - self.__last_send_time)
		if intv <= 0 then
			self:request("heartbeat")
		else
			skynet.sleep(intv*100)
		end
	end
end

local function dispatch_msg(self, msg)
	if self.__closed then return end
	--fetch head here
	if h.encodeFlag == true then
		msg = crypt.aesdecode(msg, hs.passwd, "")	
	end
	msg = string.sub(msg, 11, #msg)
	local t = {host:dispatch(msg)}
	local type = t[1]
	if type == "REQUEST" then
		local name, args, response = t[2], t[3], t[4]
		logger.info('REQUEST:%s', name)
		if self.__request then
			return self.__request(name, args, response_function(self, response))
		end
	else
		assert(type == "RESPONSE")
		local session, resp = t[2], t[3]
		local f = self.__response[session]
		self.__response[session] = nil
		return f(resp)
	end
end

local function dispatch(self)
	while not self.__closed do
		local ok, data = pcall(recv_package, self)
		if not ok then
			logger.warn("client dispatch recv package error data, will exit: %s", data)
			self:close("dispatch")
            skynet.exit()
		end
		skynet.fork(dispatch_msg, self, data)
		skynet.sleep(0)
	end
end


-- request_handler = function (name, args, response) end
function client.open(svaddr, request_handler, is_encrypt, key_secret, id)
	-- connect to server
	local ip, port = string.match(svaddr, "([^:]+):(.*)$")
	port = tonumber(port)
	logger.info("robot_%s begin connecting to server, svr = %s", id, svaddr)
	local sock = socket.open(ip, port)
	if not sock then
		logger.err("robot_%s, connect to server fail, svr = %s", id, svaddr)
		return
	end
	socketdriver.nodelay(sock)
	logger.info("connect to server success, svr = %s", svaddr)
	logger.warn("is_encrypt:%s", is_encrypt)
	local self = setmetatable({
		__request = request_handler,
		__ip = ip,
		__port = port,
		__sock = sock,
		__last_send_time = 0,
		__last_heartbeat_time = os.time(),
		__session = -1,
		__response = {},
	}, client)
	if not is_encrypt then
		--skynet.fork(heartbeat, self)
		skynet.fork(dispatch, self)
		return self
	end
	return self
end

local function new_session(self)
	self.__session = self.__session + 1
	return self.__session
end

-- response = function (resp) end
function client:request(dst, module, action, name, args, response)
	if self.__closed then 
		logger.info("client:request after socket close")
		return 
	end
	local session
	if response then session = new_session(self) end
	local ok, data = pcall(request, name, args, session)
	if not ok then
		logger.warn("client pack request error, will exit: %s", data)
        skynet.exit()
	end
	--add head here
	local msg = ct.loadMsgHead(
		data,
		h.enumEndPoint.CLIENT,
		dst,
		module,
		action
	)
	ok, data = pcall(send_package, self, msg)
	if not ok then
		logger.warn("client send request error: %s", data)
		return self:close("client request")
	end
	if response then self.__response[session] = response end
	return true
end

function client:close(who)
	if self.__closed then return end
	logger.info("client close socket, who:%s", who)
	self.__closed = true
	pcall(socket.close, self.__sock)
	self.__sock = nil
	for k,v in pairs(self.__response) do
		skynet.fork(function () v() end)
	end
	self.__response = nil
end

function client:closed()
	return self.__closed
end

return client


local skynet = require "skynet"
local futil = require "utils.futil"
local handler = require "client_handler"
local logger = require "logger"
local ct = require "common_lib"
local h = require "head_file"
local hs = require "headfile_server"
local json = require "cjson"
local gd = require "glzp.gamedata"

local g_param

local const
local authData
local userInfo 
local deskInfo = {}
local REQUEST = handler.__request
local RESPONSE = handler.__response

function REQUEST:testS2C(args)
	logger.err('testS2C')
end

--处理服务器推送消息
function REQUEST:flushGoods(args)
	logger.debug('flushGoods:%s', futil.toStr(args))
end

function handler:setup(param)
    assert(param)
    g_param = param
    self.openid = "robot"..self.id
end

function handler:run()
    local ctx = self.ctx

	if not self.cl:closed() then
		authData = handler.auth
		self.auth = handler.auth
		userInfo = self.auth.userInfo_
		logger.info('auth data:%s', futil.toStr(authData))
        logger.info("TODO: 登陆成功,在这里运行你的第一行代码")

		--发请求给服务器
		local ok, rv = pcall(self.request, self, h.enumEndPoint.LOBBY_SERVER, 0, 
			h.enumKeyAction.GET_PLAYER_STATUS, 'getPlayerStatus')
		if ok then
			logger.debug('getPlayerStatus:%s', futil.toStr(rv))
		end
    end

	logger.info("handler.run end, id = %s", self.id)
end


skynet.init(function()
	const = require "const"
end)


return handler


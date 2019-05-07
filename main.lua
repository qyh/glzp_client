local skynet = require "skynet"
require "utils.functions"
local logger = require "logger"
local json = require "json"
require "skynet.manager"

skynet.start(function()
	skynet.newservice('logservice')
	skynet.newservice("client_service")
	logger.info("client started")
	skynet.exit()
end)

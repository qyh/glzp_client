local skynet = require "skynet"
require "skynet.manager"
local const = require "const"
local futil = require "futil"
local logObj = nil
local log_dir = skynet.getenv("logpath") or "./log"
local daemon = skynet.getenv("daemon") or nil
local command ={}
local filename = skynet.getenv("name")

local loglevel = const.loglevel
local logBeginTime = nil 

local function open_log_file()
    if logObj then
        return true
    end
    if not logObj then
        os.execute('mkdir -p '..log_dir)
		local log_full_name = log_dir.."/"..filename.."_"..futil.dayStr()..".log"
        logObj = io.open(log_full_name, "a+")
        if logObj then
            skynet.error(string.format("open log file:%s success", log_full_name))
			logBeginTime = os.time()
            return true
        else
            skynet.error(string.format("open log file:%s error", log_full_name))
            return false
        end
    end
    return false 
end
local function timerflush()
	if logObj then
		logObj:flush()
	end
	skynet.timeout(500, timerflush)
end
local function color_print(level, content)
    local color_str = ""
    if level == loglevel.debug then
        color_str = string.format("\27[0;34m%s\27[0m", content)
    elseif level == loglevel.warn then
        color_str = string.format("\27[1;33m%s\27[0m", content)
    elseif level == loglevel.err then
        color_str = string.format("\27[0;31m%s\27[0m", content)
    else 
        color_str = content
    end
    io.write(color_str)
    io.flush()
end

local function write_log(content)
	if not futil.is_same_day(logBeginTime, os.time()) then
		if logObj then
			logObj:flush()
			logObj:close()
		end
		local log_full_name = log_dir.."/"..filename.."_"..futil.dayStr()..".log"
		logObj = io.open(log_full_name, "a+")
		if logObj then
			logBeginTime = os.time()
		else
			skynet.error(string.format("open logfile:%s error", log_full_name))
			return
		end
	end
    logObj:write(content)
end
function command.log(source, level, t, msg)
    if not logObj then
        skynet.error("logObj object is nil")
        return
    end
    if level == loglevel.info then
        lvl_str = "info"
    elseif level == loglevel.warn then
        lvl_str = "warn"
    elseif level == loglevel.err then
        lvl_str = "error"
    elseif level == loglevel.debug then
        lvl_str = "debug"
    else
        skynet.error(string.format("unkonwn log level:%s", level))
        return 
    end
    local t_str = os.date("%Y-%m-%d %H:%M:%S", t)
    local content = string.format("[%s][%s][%s] %s\n", skynet.address(source), t_str, lvl_str, msg)
	write_log(content)
    if daemon == nil then
        color_print(level, content)
    end
end


skynet.start(function () 
    skynet.dispatch("lua", function(session, source, cmd, ...) 
        local f = command[cmd]
        if f then 
            return f(source, ...)
        else
            skynet.error(string.format("can not found command:%s", cmd))
        end
    end)
    open_log_file()
	timerflush()
    skynet.register(".logservice")
end)

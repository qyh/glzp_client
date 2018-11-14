local skynet = require "skynet"
local ct = require "glzp.common_lib"  
local logger = {}
local level = {
	debug = 0,
	info = 1,
	error = 2,
	warn = 3,
}
local function color_print(lvl ,str)
	local msg
	if lvl == level.error then
		msg = "\27[31m"..str.."\27[37m"
	elseif lvl == level.info then
		msg = "\27[37m"..str.."\27[37m"
	elseif lvl == level.debug then
		msg = "\27[34m"..str.."\27[37m"
	elseif lvl == level.warn then
		msg = "\27[33m"..str.."\27[37m"
	end
	print(msg)
end
function logger.warn(...)
	local str = ct.getTime()..'[warn] '..string.format(...)
	skynet.error(str)
	color_print(level.warn, str)
end
function logger.debug(...)
	local str = ct.getTime()..'[debug] '..string.format(...)
	skynet.error(str)
	color_print(level.debug, str)
end

function logger.info(...)
	local str = ct.getTime()..'[info] '..string.format(...)
	skynet.error(str)
	color_print(level.info, str)
end
function logger.err(...)
	local str = ct.getTime()..'[error] '..string.format(...)
	skynet.error(str)
	color_print(level.error, str)
end
return logger

local json = require "json"
require "tostring"
local futil = {}
-- 一天的秒数
local ONE_DAY_SEC = 86400
-- 一周的秒数
local ONE_WEEK_SEC = 604800
-- 两周的秒数
local TWO_WEEKS_SEC = 1209600

futil.ONE_DAY_SEC = ONE_DAY_SEC
futil.ONE_WEEK_SEC = ONE_WEEK_SEC
futil.TWO_WEEKS_SEC = TWO_WEEKS_SEC

function futil.split(s, sep)
	local sep = sep or " "
	local fields = {}
	local pattern = string.format("([^%s]+)", sep)
	string.gsub(s, pattern, function(c) fields[#fields+1]=c end)
	return fields
end

function futil.repl(s, params)
	if params == nil then return s end
	if type(params) ~= 'table' then
		return string.gsub(s, '{[%d]+}', params)
	end
	return string.gsub(s, '{[%d]+}', function (ss)
		local n = tonumber(ss:sub(2, -2))
		return params[n+1]
	end)
end

function futil.nowstr(now)
	return os.date("%Y-%m-%d %H:%M:%S", now or os.time())
end

--a shorter name
function futil.now()
	return os.date("%Y-%m-%d %H:%M:%S", os.time())
end

-- t is return by os.time()
function futil.dayStr(t)
	return os.date("%Y%m%d", t or os.time())
end
function futil.now_date(time)
	return os.date("%Y-%m-%d", os.time())
end
function futil.get_date_str(t)
	return os.date("%Y%m%d", t)
end
function futil.get_date_hour_str(t)
	return os.date("%Y%m%d%H", t)
end
function futil.strTimeTz(t, tz)
	t = t or os.time()
	tz = tz or 0
	return os.date("!%F %T", t+tz*3600)
end

function futil.getYesterdayTimeStrFmt(nowTime)
	local nowTab = os.date("*t", nowTime)
	nowTab.hour = 0
	nowTab.min = 0
	nowTab.sec = 0

	local todayBegin = os.time(nowTab)
	local oneDaySecCnt = 24 * 3600
	return os.date("%Y-%m-%d %H:%M:%S", todayBegin - oneDaySecCnt)
end

function futil.getTimeByDate(dateStr)
	local a = futil.split(dateStr, " ")
	local b = futil.split(a[1], "-")
	if #b ~= 3 then
		return nil
	end
	local c = futil.split(a[2], ":")
	if #c ~= 3 then
		return nil
	end
	return os.time({year=b[1], month=b[2], day=b[3], hour=c[1],min=c[2],sec=c[3]})
end

function futil.getThisMonthBeginTime()
    return futil.get_month_begin_time() 
end

-- 获取指定某一周指定工作日的开始时间戳
function futil.getWeekdayBeginTime(week_day, now_time)
	-- week_day：1-7，从周一到周日
	-- now_time: 该时间戳用于指定某一周
	now_time = now_time or os.time()
	local now_tab = os.date("*t", now_time)
	now_tab.hour = 0
	now_tab.min = 0
	now_tab.sec = 0
	local today_begin = os.time(now_tab)
	-- 周日的话，将其并入上一周
	local today = now_tab.wday==1 and 7 or now_tab.wday-1
	local day_diff = week_day - today
	local begin_time = today_begin + (day_diff)*ONE_DAY_SEC
	return begin_time
end

function futil.getThisWeekBeginTime(nowTime)
	--获取一周的周一作为起始
	return futil.getWeekdayBeginTime(1, nowTime)
end

--return string, like '20150928'
function futil.getThisWeekBeginDate(nowTime)
	--获取一周的周一作为起始
	local beginDate = os.date("*t", futil.getWeekdayBeginTime(1, nowTime))
	return string.format("%d%02d%02d", beginDate.year, beginDate.month, beginDate.day)
end

function futil.getLastWeekBeginTime(nowTime)
	return futil.getWeekdayBeginTime(1, nowTime) - ONE_WEEK_SEC
end

function futil.isSingleWeek(week_begin_time)
	local begin_time = 1420387200		-- 2015-01-05 0:0:0的时间戳,从这周的周一算起
	if week_begin_time < begin_time then
		return false
	end
	local sec_diff = week_begin_time - begin_time
	local isSingleWeek = sec_diff%TWO_WEEKS_SEC < ONE_WEEK_SEC
	return isSingleWeek
end

-- 获取今日指定时间的时间戳
-- clock格式, 例子：5:10:05
-- nowTime：该时间戳用于指定某一天
function futil.getTodayTimestamp(clock, nowTime)
	local nowTab = os.date("*t", nowTime)
	local _, _, hour, min, sec = string.find(clock, "(%d+):(%d+):(%d+)")
	local timestamp = os.time {year = nowTab.year, month = nowTab.month, day = nowTab.day,
		hour = hour, min = min, sec = sec}

	return timestamp
end

function futil.getTodayBeginTimestamp()
	local now_time = os.time()
	local now_tab = os.date("*t", now_time)
	now_tab.hour = 0
	now_tab.min = 0
	now_tab.sec = 0
	return os.time(now_tab)
end

function futil.getDayBeginTimestamp(timestamp)
	local time_tab = os.date("*t", timestamp)
	time_tab.hour = 0
	time_tab.min = 0
	time_tab.sec = 0
	return os.time(time_tab)
end

function futil.getNextDayInterval()
	local now_tab = os.date("*t")
	now_tab.hour = 0
	now_tab.min = 0
	now_tab.sec = 0
	return ONE_DAY_SEC - (os.time() - os.time(now_tab))
end

function futil.toStr(t)
	if not t then
		return nil
	end
	return table.tostring(t)
end
futil.tostr = futil.toStr

function futil.dump(t)
	print(futil.toStr(t))
end

function futil.countTb(t)
	if not t then
		return 0
	end
	local cnt = 0
	for _,_ in pairs(t) do
		cnt = cnt + 1
	end
	return cnt
end

-- 字符串格式化, 参数合法性由调用者保证
-- s : 要格式化的字符串
-- ... : 格式化时使用的替换参数
-- 格式化规则: 将 %% 替换为 %, 将 %n 替换成 ... 中的第 n+1 个参数, n 为 0-9 的数字
-- 返回值: 替换之后的字符串, 发生替换次数
function futil.strformat(s, ...)
	local pattern = "%%[%d%%]"

	local t = {...}
	return string.gsub(s, pattern, function (s1)
		if s1 == "%%" then
			return "%"
		else
			local p = tonumber(s1:sub(2)) + 1
			return t[p]
		end
	end)
end

function futil.dict2kvlist(d)
	local lst = {}
	if not d then return lst end
	for k, v in pairs(d) do
		table.insert(lst, k)
		table.insert(lst, v)
	end
	return lst
end

function futil.dictk2list(d)
    local list  = {}
    for k, _ in pairs(d or {}) do
        list[#list+1] = k
    end

    return list
end

function futil.kvlist2dict(r, cv_f)
	local d = {}
	if cv_f then
		for k = 1, #r, 2 do d[r[k]] = cv_f(r[k], r[k+1]) end
	else
		for k = 1, #r, 2 do d[r[k]] = r[k+1] end
	end
	return d
end

function futil.kv2dict(keys, vals, cv_f)
	local d = {}
	if cv_f then
		for i, k in ipairs(keys) do d[k] = cv_f(k, vals[i]) end
	else
		for i, k in ipairs(keys) do d[k] = vals[i] end
	end
	return d
end

function futil.addkv2list(lst, k, v)
	table.insert(lst, k)
	table.insert(lst, v)
	return lst
end

function futil.isTimeBeforeThisWeek(timestamp)
	if not timestamp then
		return false
	end
	local t = tonumber(timestamp)
	local thisWeekBeginTime = futil.getThisWeekBeginTime(os.time())
	return t < thisWeekBeginTime
end

-- 获取时间戳指定的当天的开始时间
function futil.getDayBeginTime(timestamp)
	timestamp = timestamp or os.time()
	local nowTab = os.date("*t", tonumber(timestamp))
	nowTab.hour = 0
	nowTab.min = 0
	nowTab.sec = 0

	local todayBegin = os.time(nowTab)
	return todayBegin
end

function futil.isSameDay(timestamp)
	local todayBegin = futil:getDayBeginTime(os.time())
	if timestamp >= todayBegin and timestamp < todayBegin + ONE_DAY_SEC then
		return true
	end
	return false
end

-- t1, t2 是os.time() 返回的值
function futil.is_same_day(t1, t2)
    if not(t1 and t2) then return end

	local tt1 = os.date("*t", tonumber(t1))
	local tt2 = os.date("*t", tonumber(t2))

    return (tt1.year == tt2.year and 
           tt1.month == tt2.month and 
           tt1.day == tt2.day)
end

-- t1, t2 是os.time() 返回的值
-- 星期一是周一
function futil.is_same_week(t1,t2)
    if not(t1 and t2) then return end
    local y1, w1 = os.date("%Y_%V", t1):match("([0-9]+)_([0-9]+)") 
    local y2, w2 = os.date("%Y_%V", t2):match("([0-9]+)_([0-9]+)") 
    
    if not (y1 and w1 and y2 and w2) then return end

    return (y1 == y2 and w1 == w2)
end

-- t1, t2 是os.time() 返回的值
-- 星期天是周一
function futil.is_same_weekU(t1, t2)
    if not(t1 and t2) then return end
    local y1, w1 = os.date("%Y_%U", t1):match("([0-9]+)_([0-9]+)") 
    local y2, w2 = os.date("%Y_%U", t2):match("([0-9]+)_([0-9]+)") 
    
    if not (y1 and w1 and y2 and w2) then return end

    return (y1 == y2 and w1 == w2)
end

function futil.round_integer(num, round_up)
	local d = math.floor(num)
	local f = num - d
	if f >= (round_up or 0.5) then
		return d + 1
	end
	return d
end

function futil.tointeger(num, is_ceil)
	local val = math.tointeger(num)
	if val then
		return val
	end
	val = tonumber(num)
	if not val then return end
	if is_ceil then
		return math.ceil(val)
	end
	return math.floor(val)
end

function futil.maxn(t)
    local n = #t
    local k = next(t, n)
    while k do
        if type(k) == "number" and k > n and math.tointeger(k) then n = k end
        k = next(t, k)
    end
    return n
end

function futil.hourBeginTime(t)
	t = t or os.time()
	return t - t % 3600
end

function futil.nextHourBeginTime(t)
	local hour_begin_time = futil.hourBeginTime(t)
	local next_hour_begin_time = hour_begin_time + 3600
	return next_hour_begin_time
end

-- timeGen: 时间戳生成器，成功返回table{秒，微秒}, 失败nil
-- nodeid: 服务器节点号
-- seqid: 用户自定义序列号起始值，1-1023
-- 返回值：成功返回64bit整数，失败返回nil
function futil.uid_gen(timeGen, nodeid, seqid)
	seqid = seqid or 1
	nodeid = nodeid or 1
	local t_shift = 1451577600		-- 时间偏移，忽略2016-01-01以前的时间
	local generator = function()
		local ts = timeGen()
		if not ts then
			return nil
		end
		if (not ts[1]) or (not ts[2]) then
			return nil
		end

		seqid = seqid + 1
		if seqid > 1023 then
		    seqid = 1
		end

		local timeVal = (tonumber(ts[1]) - t_shift)*1000 + math.floor(tonumber(ts[2])/1000)
		local id = (timeVal << 22) + (nodeid << 10) + seqid
		return id
	end
	return generator
end

function futil.parse_version(ver)
	if not ver then return end
	local fields = {}
	string.gsub(ver, "([^.]+)", function(c) table.insert(fields, tonumber(c)) end)
	return #fields > 0 and fields or nil
end

--return 0:equal, 1:ver1 > ver2, -1:ver1 < ver2
function futil.compare_version(ver1, ver2)
	local f1 = futil.parse_version(ver1)
	local f2 = futil.parse_version(ver2)
	if not (f1 and f2) then
		error(string.format("compare_version fail parse_version: %s, %s", ver1, ver2))
	end
	local len1 = #f1
	local len2 = #f2
	if not (len1 > 0 and len2 > 0 and len1 == len2) then
		error(string.format("compare_version fail invalid version: %s, %s", ver1, ver2))
	end
	for i = 1, len1 do
		local v1, v2 = f1[i], f2[i]
		if v1 > v2 then
			return 1
		elseif v1 < v2 then
			return -1
		end
	end
	return 0
end

--生成Tlog序列号(32位整数)
function futil.getTlogSequence()
	return os.time()
end

function futil.urlencode(s)
	s = string.gsub(s, "([^%w%.%- ])", function(c) return string.format("%%%02X", string.byte(c)) end)
	return string.gsub(s, " ", "+")
end

function futil.urldecode(s)
	s = string.gsub(s, "%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
	return string.gsub(s, "+", " ")
end

function futil.isValidIp(ip)
	if not ip then return false end
	local sps = futil.split(ip, ".")
	if #sps ~= 4 then return false end
	for k, v in pairs(sps) do
		local val = tonumber(v)
		if not val or val < 0 or val > 255 then
			return false
		end
	end
	return true
end

function futil.isClientIP(ip)
	if not ip then return false end
	local sps = futil.split(ip, ".")
	if #sps ~= 4 then return false end
	for i, v in ipairs(sps) do
		local val = tonumber(v)
		if not val or val < 0 or val > 255 then
			return false
		end
	end
	local val1 = tonumber(sps[1])
	local val2 = tonumber(sps[2])
	if val1 == 0 or val1 == 10 or val1 >= 224 then
		return false
	end
	if val1 == 192 and val2 == 168 then
		return false
	end
	if val1 == 172 and val2 >= 16 and val2 <= 31 then
		return false
	end
	return true
end

function futil.is_guid(guid, length)
	if not guid or type(guid) ~= "string" then
		return false
	end
	if string.len(guid) ~= length then
		return false
	end
	for i = 1, length do
		local v = string.byte(guid, i)
		if v < 48 or v > 102 or (v > 57 and v < 65) or (v > 70 and v < 97) then
			return false
		end
	end
	return true
end

function futil.month_days(year, month)
	if not year then year, month = tonumber(os.date("%Y")), tonumber(os.date("%m")) end
	return tonumber(os.date("%d", os.time({year = year, month = month + 1, day = 0})))
end

function futil.get_month_begin_time(now)
	now = now or os.time()
	local date_tbl = os.date("*t", now)
	date_tbl.day = 1
	date_tbl.hour = 0
	date_tbl.min = 0
	date_tbl.sec = 0
	return os.time(date_tbl)
end

function futil.get_xg_alias(runenv, uid)
	return string.format("%s#%s", runenv or "", uid)
end

function futil.equal_uid(uid1, uid2)
	return tostring(uid1) == tostring(uid2)
end

function futil.handle_err(e)
	return debug.traceback(coroutine.running(), tostring(e), 2)
end

function futil.slicer(array, slice_size, func)
	-- 将一个table分片处理
	local t = {}
	for _, v in pairs(array) do
		table.insert(t, v)
		if #t >= slice_size then
			local arg = t
			t = {}
			func(arg)
		end
	end
	if #t > 0 then
		func(t)
	end
end

function futil.slicer_if(array, slice_size, IF_func, func)
	-- 将一个table分片处理, 被处理的元素会使IF_func为true
	local t = {}
	for _, v in pairs(array) do
		if IF_func(v) then
			table.insert(t, v)
			if #t >= slice_size then
				local arg = t
				t = {}
				func(arg)
			end
		end
	end
	if #t > 0 then
		func(t)
	end
end

function futil.slice_gen(range_begin, range_end, size)
	return function()
		assert(size > 0)
		if range_begin > range_end then
			return nil
		end
		local e = math.min(range_begin + size, range_end)
		local t = {
			rbegin = range_begin,
			rend = e,
		}
		range_begin = e + 1
		return t
	end
end

function futil.int2bool(i)
	if i == 0 then
		return false
	end
	return true
end

--序列化数组, 如:[a,b,c,d]序列化成"a,b,c,d"
function futil.packarr(arr)
	return table.concat(arr, ",")
end

--反序列化字符串, 如:"a,b,c,d"反序列化成[a,b,c,d]
--confn:convert function, 可默认为空, 作用于值上，进行定制，若不提供此函数，则用原值
function futil.unpackarr(arrStr, confn)
	if not arrStr or #arrStr == 0 then
		return {}
	end
	local arr = futil.split(arrStr, ",")
	if (not arr) or (#arr == 0) then
		return {}
	end
	if confn then
		for k, v in pairs(arr) do
			arr[k] = confn(v)
		end
	end
	return arr
end

function futil.firstkv(t)
	for k,v in pairs(t) do return k,v end
end

function futil.traverseTable(t, fn)
	for k, v in pairs(t) do
		t[k] = fn(v)
	end	
end

function futil.tryToNumber(s)
	local ret = tonumber(s)
	return ret or s
end

function futil.strToDate(s, sTime)
	local t = {}
	if sTime then
		t.year, t.month, t.day = s:match("(%d+)-(%d+)-(%d+)")
		t.hour, t.min, t.sec = sTime:match("(%d+):(%d+):(%d+)")
	else
		t.year, t.month, t.day, t.hour, t.min, t.sec = s:match("(%d+)-(%d+)-(%d+)%s+(%d+):(%d+):(%d+)")
	end
	for k,v in pairs(t) do t[k] = tonumber(v) end
	return t
end

function futil.strToTime(s, sTime)
	return os.time(futil.strToDate(s, sTime))
end

function futil.hasSameKeys(mainTable)
	local keys
	local keyCnt = 0
	for _, subTable in pairs(mainTable) do
		if not keys then
			keys = {}
			for k, _ in pairs(subTable) do
				keys[k] = true
				keyCnt = keyCnt + 1
			end
		else
			local curCnt = 0
			for k, _ in pairs(subTable) do
				if not keys[k] then
					return false
				end
				curCnt = curCnt + 1
			end
			if curCnt ~= keyCnt then
				return false
			end
		end
	end
	return true
end

--return like: 20150108
function futil.getNumOfDate(theTime)
	return tonumber(os.date("%Y%m%d", theTime))
end

function futil.anotherDayRefresh(lastTime, atTime)
	local hour_sec = 3600
	atTime = atTime or 0
	local lastTimeShift = 0
	if lastTime ~= 0 then
		lastTimeShift = lastTime - hour_sec * atTime
	end
	local lastDate = os.date("%x", lastTimeShift)
	local curDate = os.date("%x", os.time() - hour_sec * atTime)
	if lastDate ~= curDate then
		return true
	else
		return false
	end
end

function futil.anotherWeekRefresh(lastTime)
	local now = os.time()
	lastTime = tonumber(lastTime)
	local now_week_begin_time = futil.getThisWeekBeginTime(now)
	local last_week_begin_time = futil.getThisWeekBeginTime(lastTime)
	if now_week_begin_time ~= last_week_begin_time then
		return true
	else
		return false
	end
end

function futil.strKey2NumKey(t)
	local res = {}
	for k,v in pairs(t) do res[tonumber(k)] = v end
	return res
end

function futil.numKey2StrKey(t)
	local res = {}
	for k,v in pairs(t) do res[tostring(k)] = v end
	return res
end

function futil.getTimeByRankID(rank_id)
	if not rank_id or rank_id <= 0 then
		return 0
	end
	local year = math.floor(rank_id / 10000)
	rank_id = rank_id % 10000
	local month = math.floor(rank_id / 100)
	local day = rank_id % 100
	return os.time {year = year, month = month, day = day, hour = 0, min = 0, sec = 0}
end

function futil.getTimeByYear(dateStr)
	local b = futil.split(dateStr, "-")
	if #b ~= 3 then
		return nil
	end
	return os.time({year=b[1], month=b[2], day=b[3], hour=0, min=0, sec=0})
end

function futil.gt_min(min)	-- greater than min
	return function(v)
		if not v then
			return v
		end
		return (v > min and v or nil)
	end
end

function futil.not_empty_array(v)
	if not v then
		return nil
	end
	return (#v > 0 and v or nil)
end

-- 过滤特殊字符，保留中文，英文和数字
function futil.filter_spec_chars(s)
	local ss = {}
	for k = 1, #s do
		local c = string.byte(s,k)
		if not c then break end
		if (c>=48 and c<=57) or (c>=65 and c<=90) or (c>=97 and c<=122) then
			table.insert(ss, string.char(c))
		elseif c>=228 and c<=233 then
			local c1 = string.byte(s, k+1)
			local c2 = string.byte(s, k+2)
			if c1 and c2 then
				local a1,a2,a3,a4 = 128,191,128,191
				if c == 228 then a1 = 184
				elseif c == 233 then a2,a4 = 190,c1~=190 and 191 or 165 
				end
				if c1>=a1 and c1<=a2 and c2>=a3 and c2<=a4 then
					k = k + 2
					table.insert(ss, string.char(c,c1,c2))
				end
			end
		end
	end
	return table.concat(ss)
end

function futil.getDayTime(t)
	t = t or os.time()
	return t - futil.getDayBeginTime(t)
end

function futil.create_cycle_counter(start, max_value, step)
	local _s = start or 1
	start = _s
	step = step or 1
	max_value = max_value or 0x7fffffff
	return function()
		if start > max_value then
			start = _s
		end
		local val = start
		start = start + step
		return val
	end
end

function futil.short_name(nodename)
	return string.match(nodename, "^[^#]+")
end

function futil.is_today_ts(ts)
	local tt = os.date("*t", ts)
	local current = os.date("*t", os.time())
	return tt.year == current.year and tt.yday == current.yday
end

-- 从数组中随机抽取多个元素
function futil.array_rand(arr, num_req)
	num_req = num_req or 1
	local num_avail = #arr
	if num_req == num_avail then
		return arr
	end
	if num_req <= 0 or num_req > num_avail then
		error(string.format("array_rand unexpected param %s %s", #arr, num_req))
	end
	local r = {}
	for _, v in pairs(arr) do
		if num_req == 0 then
			break
		end
		if math.random() < num_req/num_avail then
			table.insert(r, v)
			num_req = num_req - 1
		end
		num_avail = num_avail - 1
	end
	return r
end

function futil.shuffle(arr)
	local n = #arr
	for i=1, n do
		local rindex = math.random(i, n)
		arr[i], arr[rindex] = arr[rindex], arr[i]
	end
end


local SHORT_BASE = {           -- 不能改动
	'A','B','C','D','E','F','G','H',
	'J','K','L','M','N','P','Q','R',
	'S','T','U','V','W','X','Y','Z',
	'2','3','4','5','6','7','8','9',
}
local SHORT_PRE = "fish3d_pre" -- 不能改动

function futil.short_url(str)
	local md5 = require "md5"
	local m = md5.sumhexa(SHORT_PRE..str)
	local ret = {}
	for k=0,3 do
		local sub = string.sub(m, k*8+1, k*8+8)
		local int =  0x3fffffff & tonumber(sub, 16)
		local out = ''
		for j=1,6 do
			local v = ( 0x1f & int) + 1
			out = out .. SHORT_BASE[v]
			int = int >> 5
		end
		table.insert(ret, out)
	end
	return ret
end

local short_url_base = {}
setmetatable(short_url_base, {
	__newindex = function(t, k, v)
		error("short_url_base change disabled!")
	end,
	__index = function(t, k)
		return rawget(SHORT_BASE, k)
	end
})
function futil.short_url_base()
	return short_url_base, #SHORT_BASE
end

function futil.sum(t)
	local s = 0
	for _, v in pairs(t) do
		s = s + v
	end
	return s
end

function futil.get_short_ver(long_ver, n)
	assert(n and n > 0)
	local pattern = string.rep("(%d+)", n, ".")
    local ret = table.pack(long_ver:match(pattern))
    if #ret < n then
    	error(string.format("get_short_ver fail, n too big, args = %s, %s", long_ver, n))
    end
    local s = table.concat(ret, ".", 1, n)
    return s
end

-- 轮盘赌
function futil.run_roulette(values, weights, sum_weight)
	assert(#values == #weights, "values和weights不一致")
	if sum_weight == 0 then
		return 1, values[1]
	end

	local tmp_weight = math.random(1, sum_weight) 
	local weight = 0
	for k, v in ipairs(weights) do
		weight = weight + v
		if tmp_weight <= weight then
			return k, values[k]
		end
	end
	return 1, values[1]
end

-- 版本检测
function futil.check_config_version(config, type, short_ver)
	local cfg = config[type]
	if cfg and short_ver then
		if cfg.min_version and futil.compare_version(short_ver, cfg.min_version) < 0 then
			return false
		end
	end
	return true
end

-- 鱼阵刷新版本检测
function futil.check_fish_script_version(config, array, index, short_ver)
	local value = array[index]
	if not value then
		return 1, nil
	end
	local cfg = config[value]
	if not futil.check_config_version(config, value, short_ver) then
		local index_1, index_2
		for k,v in pairs(array) do
			cfg = config[v]
			if futil.check_config_version(config, v, short_ver) then
				if k < index then
					index_1 = k
				else
					index_2 = k
				end
			end
		end
		if not index_1 and not index_2 then
			return index, nil
		end
		index = index_2 or index_1
	end
	return index, array[index]
end

-- 刷鱼版本检测
function futil.check_fish_version(player, config, fish_config, ver_spawn_fish_config)
	if not player then
		return 1
	end
	local id = config.id
	local cfg = fish_config[id]
	if cfg then
		if cfg.min_version and futil.compare_version(player.ac.short_ver, cfg.min_version) < 0 then
			return ver_spawn_fish_config[math.random(1, #ver_spawn_fish_config)].id
		end
	end
	return id
end

--t = {xx = xx, xx = xx, ...}
--keys = ...
function futil.getSelectedVals(t, ...)
	local keys = {...}
	local n = #keys
	for i = 1, n do keys[i] = t[keys[i]] end
	return table.unpack(keys, 1, n)
end

function futil.dayStr2Time(dayStr)
	local nowDate = os.date("*t")
	local _, _, hour, min, sec = string.find(dayStr, "(%d+):(%d+):(%d+)")
	local day_time = os.time {year = nowDate.year, month = nowDate.month, day = nowDate.day, hour = hour, min = min, sec = sec}
	return day_time
end

-- 生成12bit cdkey, 如KmYbHdgLWn14, JggjmemUq1NU
-- !!没有和时间戳做关联，因此不保证不重复!!
function futil.gen_cdkey()
	if not futil.gen_cdkey_base then
		local a = 97
		local A = 65
		futil.gen_cdkey_base = {}
		for i=0,9 do
			table.insert(futil.gen_cdkey_base, i)
		end
		for i=65,90 do
			table.insert(futil.gen_cdkey_base, string.char(tostring(i)))
		end
		for i=97,122 do
			table.insert(futil.gen_cdkey_base, string.char(tostring(i)))
		end
	end
	local ret = ""
	for i=1,12 do
		ret = ret..futil.gen_cdkey_base[math.random(1, #futil.gen_cdkey_base)]
	end
	return ret
end
-- 把字符串格式的时间转换成os.time()
-- |strtime|: 格式为 'yyyy-mm-dd HH:MM:SS' 
-- 解析失败返回nil
function futil.str2time(strtime)
    if not strtime then return end

    local pat = "([0-2][0-9][0-9][0-9])-([0-1]?[0-9])-([0-3]?[0-9])[ ]+([0-2]?[0-9]):([0-5]?[0-9]):([0-5]?[0-9])"
    local year, month, day, hour, min, sec = string.match(strtime, pat)
    if not (year and month and day and hour and min and sec) then return end

    return os.time({year=year,month=month,day=day,hour=hour,min=min,sec=sec})
end

-- 根据身份证判断是否为成年人
-- 0no  1yes
function futil.judge_if_adult(cer)
	if #cer ~= 18 then return 0 end

	local ok, birthday = pcall(string.sub, cer, 7, 14)
	if not ok then return 0 end

	local y = tonumber(string.sub(birthday, 1, 4))
	local m = tonumber(string.sub(birthday, 5, 6))
	local d = tonumber(string.sub(birthday, 7, 8))
	if (y<1900 or y >3000) or (m<0 or m>12) or (d<0 or d>31) then return 0 end

	local timestr = string.format("%s-%s-%s 00:00:00", y, m, d)
	local _18years_sec = (3600*24) * 365 * 18
	if os.time() - futil.str2time(timestr) < _18years_sec then return 0 end

	return 1
end

function futil.gen_id(salt)
    local id = nil
    local t = os.date("%Y%m%d%H%M%S", os.time())
    local clock = math.random(10000,100000)--math.floor(os.clock()*1000000)
    salt = salt 
    if salt then
        id = string.format("%s%s%s", t, clock, salt)
    else
        id = string.format("%s%s", t, clock)
    end
    return id
end

function futil.get_min(array)
	if not (array and next(array)) then
		return
	end
	local min = array[1]
	for k, v in pairs(array) do
		min = min > v and v or min		
	end
	return min
end
function futil.get_max(array)
	if not (array and next(array)) then
		return 0
	end
	local max = array[1]
	for k, v in pairs(array) do
		max = max < v and v or max 
	end
	return max 
end
function futil.is_in_array(array, value)
	for k, v in pairs(array) do
		if v == value then
			return true
		end
	end
	return false
end
function futil.get_length(param)
	if type(param) == 'string' then
		return #param
	elseif type(param) == 'table' then
		local s = 0
		for k, v in pairs(param) do
			s = s + 1
		end
		return s
	else
		error('get_length not support type:%s', type(param))
	end
	return 0
end

function futil.get_cell_by_factor(fac)
	local ret = 1
	for _, n in pairs {1,10,50,80,100,200,300,500,1000} do
		if fac < n then
			break
		else
			ret = n
		end
	end
	return ret
end
function futil.handle_error(e)
	--从第2层堆栈开始打印出错信息
	return debug.traceback(coroutine.running(), tostring(e), 2)
end

return futil


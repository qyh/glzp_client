local skynet = require "skynet"
local futil = require "utils.futil"
local handler = require "client_handler"
local logger = require "logger"
local ct = require "glzp.common_lib"
local h = require "glzp.head_file"
local hs = require "glzp.headfile_server"
local json = require "cjson"
local gd = require "glzp.gamedata"

local g_param

local const
local authData
local userInfo 
local deskInfo = {}
local REQUEST = handler.__request
local RESPONSE = handler.__response
local balanceCo = nil
--所有吃牌序列
local allSequence = {
	{12,17,20},
	{11,12,13},
	{12,13,14},
	{13,14,15},
	{14,15,16},
	{15,16,17},
	{17,18,19},
	{18,19,20},
	{2,7,10},
	{1,2,3},
	{2,3,4},
	{3,4,5},
	{4,5,6},
	{5,6,7},
	{6,7,8},
	{7,8,9},
	{8,9,10},
}
--[[
function REQUEST:user_info(args)
    logger.debug("REQUEST:user_info %s", futil.toStr(args))
    local ctx = self.ctx
    ctx.user_info = args
    if ctx.waiting_for_user_info then
        skynet.wakeup(ctx.waiting_for_user_info)
        ctx.waiting_for_user_info = nil
    end
    skynet.fork(function (handler)
        while true do
            handler:_refresh_player_treasure()
            skynet.sleep(g_param.refresh_treasure_to or 30*100)
        end 
    end, self)

end
]]
function REQUEST:testS2C(args)
	logger.err('testS2C')
	--skynet.exit()
	handler:challengeSignIn(self.challengeId)
end
function REQUEST:notifyUseProtectTicket(args)
	logger.warn('notifyUseProtectTicket:%s', futil.toStr(args))
	local res = self:request(h.enumEndPoint.ROOM_CHALLENGE, 0, 
	h.enumKeyAction.REQ_USE_PROTECT_TICKET, 'challengeUseProtectTicket', 
	{itemId=1958, num=1, challengeId = args.challengeId})
	if (res and res.result == 0) then
		logger.warn('useProtectTicket success')
	else
		local ok, rv = pcall(self.request, self, h.enumEndPoint.ROOM_CHALLENGE, 0, h.enumKeyAction.SEND_OVER_CHALLENGE, 'sendOverChallenge', {
			challengeId=args.challengeId
		})
		handler:challengeSignIn(args.challengeId)
	end
end
function REQUEST:challengePassRecordStart(args)
	logger.warn('challengePassRecordStart:%s', futil.toStr(args))
end
function REQUEST:challengePassRecord(args)
	logger.warn('challengePassRecord count:%s', #args.passRecord)
end
function REQUEST:challengePassRecordEnd(args)
	logger.warn('challengePassRecordEnd:%s', futil.toStr(args))
end
function REQUEST:notifyChallengePlayerChange(args)
	logger.debug('notifyChallengePlayerChange:%s', futil.toStr(args))
end
function REQUEST:notifyChallengeMatchResult(args)
	logger.debug('notifyChallengeMatchResult:%s', futil.toStr(args))
	local leaveDesk = false
	if args.result == 100 then
		logger.err('kill self for test')
		--skynet.exit()
	end
	if leaveDesk then
		if args.result == 0 then
			local data = {
				deskID = args.deskID	
			}
			local ok, rv = pcall(self.request, self, h.enumEndPoint.ROOM_CHALLENGE, 0, h.enumKeyAction.LEAVE_DESK, 
				'leaveDesk', data)
			if ok and rv then
				logger.warn('leaveDesk result:%s', futil.toStr(rv))
			else
				logger.err('leaveDesk failed')
			end
		end
	end
end
function REQUEST:sendInfo(args)
	logger.info("sendInfo:%s", futil.toStr(args.info))
	logger.info("userInfo:%s", futil.toStr(userInfo))
	logger.debug('user %s game start', userInfo.nickName)
	self.gameStart = true
	skynet.call('.client_service', 'lua', 'gaming', self.id, true)
	for k, v in pairs(args.info) do
		if v.userID == userInfo.userID then
			deskInfo = {}
			deskInfo.deskID = v.deskID
			deskInfo.msgTag = 0
			self.agentId = v.agentId
			self.deskID = v.deskID
			logger.debug('user:%s agentId=%s,deskID:%s', userInfo.nickName, self.agentId, args.deskID)
		end
	end
end
function REQUEST:flushGoods(args)
	logger.debug('flushGoods:%s', futil.toStr(args))
end
function REQUEST:challengeOver(args)
	logger.err('challengeOver:%s,%s', userInfo.nickName, futil.toStr(args))
	skynet.sleep(500)
	if args.winCount == self.conf.totalWinCount then
		if futil.randomWheel(100, g_param.rechallengeOnPass) then
			logger.warn('%s rechallengeOnPass OK', userInfo.userID)
			handler:challengeSignIn(self.challengeId)
		end
	else
		if futil.randomWheel(100, g_param.rechallengeOnFail) then
			logger.warn('%s rechallengeOnFail OK', userInfo.userID)
			handler:challengeSignIn(self.challengeId)
		end
	end
end

function handler:setup(param)
    assert(param)
    g_param = param
    self.openid = "robot"..self.id
	self.challengeId = tonumber(param.challengeId)
end

function handler:_cheat()
    logger.info("%s using gm", self.openid)
end

function REQUEST:setHandCards(args)
	logger.info('setHandCards:%s', futil.toStr(args))
	local handCards = args.handCards
	deskInfo.handCards = {} 
	for i=1, 21 do
		deskInfo.handCards[i] = 0
	end
	for k, v in pairs(handCards) do
		deskInfo.handCards[v] = (deskInfo.handCards[v] or 0) + 1
	end
	logger.info('sorted handCards:%s', futil.toStr(deskInfo.handCards))
end

function REQUEST:doPlayCard(args)
	logger.debug('doPlayCard:%s', futil.toStr(args))
end
function handler:playCard(data)
	return pcall(self.request, self, h.enumEndPoint.ROOM_CHALLENGE, 0, h.enumKeyAction.PLAY_GAME, 'playCard', data)
end
function handler:requestAction(data)
	return pcall(self.request, self, h.enumEndPoint.ROOM_CHALLENGE, 0, h.enumKeyAction.PLAY_GAME, 
	'requestAction', data)
end
function REQUEST:cancelAct(data)
	logger.debug('cancelAct:%s', futil.toStr(data))
end
--获取最臭的一张牌
function handler:getSmellyCard(handCards)
	local function hasSquence(cardID, handCards)
		for k, seq in pairs(allSequence) do
			local inSeq = false
			local hasSeq = true
			for _, id in pairs(seq) do
				if id == cardID then
					inSeq = true
					break
				end
			end
			if inSeq then
				for _, id in pairs(seq) do
					if cardID ~= id then
						if handCards[id] ~= 1 then
							hasSeq = false
							break
						end
					end
				end
			end
			if inSeq and hasSeq then
				return true
			end
		end
		return false
	end
	local piv = 10
	local smellyID = nil
	for i=1, 20 do 
		local cardID = i
		local num = handCards[i]
		if num == 1 then
			if cardID <= piv then
				--小写数字的牌
				if handCards[cardID + piv] ~= 2 and hasSquence(cardID, handCards) == false then
					smellyID = cardID
					break
				end
			else
				--大写数字的牌
				if handCards[cardID - piv] ~= 2 and hasSquence(cardID, handCards) == false then
					smellyID = cardID
					break
				end
			end
		end
	end
	return smellyID
end
function REQUEST:notifyPlayCard(args)
	logger.debug('notifyPlayCard:%s', futil.toStr(args))
	logger.debug('cur handCards:%s', futil.toStr(deskInfo.handCards))
	deskInfo.msgTag = args.msgTag
	local succ = false
	local tmpNum = 0 
	local smellyCardID = handler:getSmellyCard(deskInfo.handCards)
	if smellyCardID then
		logger.warn('smellyCardID:%s', smellyCardID)
		local ok, rv = handler:playCard({
			cardId = smellyCardID,
			msgTag = deskInfo.msgTag,
			deskID = deskInfo.deskID
		})
		if ok and rv.isLegal > 0 then
			logger.warn('play smellyCard:%s success', smellyCardID)
			deskInfo.handCards[smellyCardID] = deskInfo.handCards[smellyCardID] - 1
			succ = true
		else
			logger.err('play smellyCard:%s failed', smellyCardID)
		end
	else
		logger.err('smellyCardID nil')
	end
	while not succ do
		tmpNum = tmpNum + 1
		if tmpNum > 3 then
			break
		end
		--优先出只有一张的牌，再出2，3张的。。
		for cardID, num in pairs(deskInfo.handCards) do
			if num == tmpNum then
				local ok, rv = handler:playCard({
					cardId = cardID,
					msgTag = deskInfo.msgTag,
					deskID = deskInfo.deskID,
				})
				if ok then
					if rv.isLegal ~= 0 then
						logger.debug('playCard res:%s', futil.toStr(rv))
						succ = true
						--table.remove(deskInfo.handCards, k)
						deskInfo.handCards[cardID] = deskInfo.handCards[cardID] - 1
						break
					else
						logger.warn('playCard res:%s', futil.toStr(rv))
					end
				else
					logger.err('playCard res:%s', futil.toStr(rv))
				end
			end
		end
	end
	if succ then
		logger.debug('out card success')
	else
		logger.err('out card failed')
	end
end
function handler:getEatDetail(cardID, handCards)
	for k, seq in pairs(allSequence) do
		local inSeq = false
		local hasSeq = true
		for _, id in pairs(seq) do
			if cardID == id then
				inSeq = true
				break
			end
		end
		if inSeq then
			for _, id in pairs(seq) do
				if cardID ~= id then
					if handCards[id] ~= 1 then
						hasSeq = false
						break
					end
				else
					if handCards[id] ~= 0 then
						hasSeq = false
						break
					end
				end
			end
		end
		if inSeq and hasSeq then
			return seq
		end
	end
	return nil
end
function REQUEST:notifySelect(args)
	logger.info('notifySelect:%s', futil.toStr(args))
	deskInfo.msgTag = args.msgTag
	local actionId = gd.ACT_PRI.DISCARD
	local cardId = args.cardId
	local actName = args.actName
	local eatDetail = nil 
	if actName then
		local done = false
		for k, v in pairs(actName) do
			if v == gd.ACT_PRI.HU or v == gd.ACT_PRI.BUMP or v == gd.ACT_PRI.SWEEP_PASS
				or v == gd.ACT_PRI.SWEEP_ALL_H or v == gd.ACT_PRI.SWEEP_ALL_D 
				or v == gd.ACT_PRI.OPEN_GEST_H or v == gd.ACT_PRI.OPEN_GEST_D_F 
				or v == gd.ACT_PRI.OPEN_GEST_D_B then
				actionId = v
				for id, num in pairs(deskInfo.handCards) do
					if id == cardId then
						deskInfo.handCards[id] = deskInfo.handCards[id] + 1
					end
				end
				done = true
				break
			end
		end
		if not done then
			for k, v in pairs(actName) do
				if v == gd.ACT_PRI.EAT then
					logger.warn('notifySelect EAT:%s', futil.toStr(args))
					logger.warn('curhandCards:%s', futil.toStr(deskInfo.handCards))
					eatDetail = handler:getEatDetail(cardId, deskInfo.handCards)
					if eatDetail then
						actionId = v
						break
					end
				end
			end
		end
	end
	local ok, rv = handler:requestAction({
		actionId = actionId,
		cardId = cardId,
		msgTag = deskInfo.msgTag,
		deskID = deskInfo.deskID,
		details = eatDetail,
	})
	if ok then
		logger.debug('requestAction res:%s', futil.toStr(rv))
		if eatDetail and next(eatDetail) then
			logger.warn('Eat card:%s success,seq:%s', cardId, futil.toStr(eatDetail))
			for _, id in pairs(eatDetail) do
				if id ~= cardId then
					deskInfo.handCards[id] = deskInfo.handCards[id] - 1
				end
			end
		end
	else
		logger.warn('requestAction failed')
	end
end

function REQUEST:doAction(args)
	logger.debug('doAction:%s', futil.toStr(args))
end
function REQUEST:notifyProtectSteps(args)
	logger.warn('notifyProtectSteps:%s', futil.toStr(args))
	skynet.sleep(500)
	if futil.randomWheel(100, g_param.keepSteps) then
		logger.warn('%s keepSteps randomWheel OK', userInfo.userID)
		local ok, rv = pcall(self.request, self, h.enumEndPoint.ROOM_CHALLENGE, 0, h.enumKeyAction.KEEP_CHALLENGE_STAGE, 'keepChallengeStage',{challengeId=args.challengeId})
		if not (ok and rv and next(rv) and rv.result == 0) then
			logger.debug('keepChallengeStage failed:%s', futil.toStr(rv))
			self:challengeSignIn(self.challengeId)	
		else
			logger.debug('keepChallengeStage:%s', futil.toStr(rv))
			self:challengeSignIn(self.challengeId)	
		end
	end
end
function REQUEST:RelieveMsg(args)
	logger.warn('RelieveMsg:%s', futil.toStr(args))
end
function REQUEST:settlement(args)
	logger.debug('settlement:%s', futil.toStr(args))
	skynet.call('.client_service', 'lua', 'gaming', self.id, false)
	self.gameStart = false
	self.isSignIn = false
	skynet.sleep(100)
	local goldChange = 0
	local oldWinCount = userInfo.winCount
	for k, v in pairs(args.agentInfo) do
		if v.agentId == self.agentId then
			userInfo.winCount = v.winInfo
			goldChange = v.goldChange
			logger.debug('goldCoin:%s, goldChange:%s, winCount:%s', v.goldCoin, v.goldChange, v.winInfo)
		end
	end
	local maxStage = self.conf.totalWinCount
	
	balanceCo = coroutine.running()
	skynet.timeout(500, function()
		if balanceCo then
			skynet.wakeup(balanceCo)	
			balanceCo = nil
		end
	end)
	skynet.wait()
	if args.huAgentId == self.agentId then
		logger.debug('user:%s win:%s', userInfo.nickName,userInfo.winCount)
		if userInfo.winCount >= maxStage then
			local ok, rv = pcall(self.request, self, h.enumEndPoint.ROOM_CHALLENGE, 0, h.enumKeyAction.SEND_OVER_CHALLENGE, 'sendOverChallenge', {
				challengeId=self.challengeId
			})
			if ok then
				logger.err('overchallenge:%s', futil.toStr(rv))
			end
		else
			if userInfo.winCount < maxStage then
				local ok, rv = pcall(self.request, self, h.enumEndPoint.ROOM_CHALLENGE, 0, h.enumKeyAction.NEXT_CHALLENGE_STAGE, 'nextChallengeStage', {
					challengeId=self.challengeId
				})
				if ok then
					logger.debug('nextChallengeStage:%s', futil.toStr(rv))
					skynet.sleep(100)
					if rv.result ~= 0 then 
						handler:challengeSignIn(self.challengeId)
					end
				end
			end
		end
	elseif goldChange < 0 then
		logger.debug('user:%s lose winCount:%s', userInfo.nickName, oldWinCount)
	else
		logger.debug('user:%s not lose and not win, winCount:%s', userInfo.nickName,oldWinCount)
		self:challengeSignIn(self.challengeId)	
	end
end

function handler:challengeSignIn(challengeId)
	local suc = false
	while true do
		local ok, rv = pcall(self.request, self, h.enumEndPoint.ROOM_CHALLENGE_MG, 0, h.enumKeyAction.CHALLENGE_SIGN_IN, 'challengeSignIn', {
			challengeId = challengeId,
			itemId = 0,
		})
		local ok, rv = pcall(self.request, self, h.enumEndPoint.ROOM_CHALLENGE_MG, 0, h.enumKeyAction.CHALLENGE_SIGN_IN, 'challengeSignIn', {
			challengeId = challengeId,
			itemId = 0,
		})
		local ec = h.challengeResultCode
		if not ok then
			logger.err('call challenge sign in error')
		else
			if rv.errCode == 0 and rv.errMsg == "OK" then
				logger.warn('challengeSignIn:%s', futil.toStr(rv))
				self.challengeId = challengeId
				self.isSignIn = true
				self.signInTime = os.time()
				self.gameStart = false
				suc = true
				break
			elseif rv.errCode == ec.GOLD_NOT_ENOUGH or 
				rv.errCode == ec.GOLD_LIMIT or rv.errCode == ec.ITEM_NOT_ENOUGH then
				if not self:useRedeemCode(g_param.redeemCode) then    --内网兑换码
					logger.err('%s 费用不足，退出', userInfo.nickName)
					skynet.exit()
					break
				end
			elseif rv.errCode == ec.INVALID_STATE then
				logger.err('invalid state, try keepChallengeStage:%s', userInfo.userID)
				local ok, rv = pcall(self.request, self, h.enumEndPoint.ROOM_CHALLENGE, 0, h.enumKeyAction.KEEP_CHALLENGE_STAGE, 'keepChallengeStage',{challengeId=challengeId})
				if not ok then
					logger.err('keepStage failed:%s', futil.toStr(rv))
				else
					logger.debug('keepStage:%s', futil.toStr(rv))
				end
			else
				logger.err('challengeSignIn failed:%s,nickName:%s', futil.toStr(rv), userInfo.nickName)
				self.isSignIn = false
			end
		end
		skynet.sleep(200)
	end
	local function check()
		local curTime = os.time()
		if self.isSignIn and (curTime - self.signInTime > 5) and (self.gameStart == false) then
			logger.err('user %s signIn but over %s sec not start', userInfo.nickName, curTime - self.signInTime)
			if curTime - self.signInTime > 900 then
				logger.err('%s exit', userInfo.nickName)
				--it will be restart after 30s
				skynet.exit()
			elseif curTime - self.signInTime > 30 then
				handler:challengeSignIn(self.challengeId)
			end
		end

		if self.isSignIn and (self.gameStart == false) then
			skynet.timeout(100, check)
		else
			logger.debug('check done:%s', userInfo.nickName)
		end
	end
	check()
	return suc 
end
function handler:useRedeemCode(code)
	local data = {
		redeemCode = code	
	}
	local ok, rv = pcall(self.request, self, h.enumEndPoint.LOBBY_SERVER,0, h.enumKeyAction.USE_REDEEM_CODE, 'useRedeemCode', data)
	if ok and rv and next(rv) and rv.result == 0 then
		logger.warn('useRedeemCode success:%s,user:%s', futil.toStr(rv), userInfo.userID)
	else
		logger.err('useRedeemCode error:%s,user:%s', futil.toStr(rv), userInfo.userID)
		ok = false
	end
	return ok
end
function handler:getChallengeInfo()
	local succ = false
	local rv = nil
	local tryTimes = 0
	while not succ do
		local ok, seasonInfo = pcall(self.request, self, h.enumEndPoint.ROOM_CHALLENGE_MG, 0, 
			h.enumKeyAction.GET_CHALLENGE_SEASON_MESSAGE, 'getChallengeSeasonMessage')
		if not ok then
			logger.err('getChallengeInfo failed')
		end
		if seasonInfo and next(seasonInfo) and seasonInfo.result == 0 and seasonInfo.seasonMessage then
			--logger.warn('allSeason:%s', futil.toStr(seasonInfo.seasonMessage))
			for k, v in pairs(seasonInfo.seasonMessage) do
				if self.challengeId == v.challengeId then
					rv = v
					self.conf = v
					succ = true
					break
				end
			end
			if not rv then
				rv = seasonInfo.seasonMessage[1]
				succ = true
			end
		else
			logger.err('getChallengeInfo failed:%s', futil.toStr(seasonInfo))
		end
		tryTimes = tryTimes + 1
		if tryTimes > 100 then
			skynet.exit()
			break
		end
		logger.err('try getChallengeInfo again...')
		skynet.sleep(100)
	end
	return succ, rv
end
function handler:test_win()
	local userInfo = self.auth.userInfo_
	local ok, seasonInfo = self:getChallengeInfo()
	if not ok then
		return false
	end
	self.isSignIn = true
	logger.debug('challengeInfo:%s', futil.toStr(seasonInfo))
	local stepInfo = self:request(h.enumEndPoint.ROOM_CHALLENGE_MG, 0, 0, 'getProtectStepsInfo', {})
	logger.err('sepInfo:%s', futil.toStr(stepInfo))
	if not self.isSignIn then 
		local v = seasonInfo
		--[[
		local res = self:request(h.enumEndPoint.ROOM_CHALLENGE, 0, 
		h.enumKeyAction.REQ_USE_PROTECT_TICKET, 'challengeUseProtectTicket', {itemId=1958, num=1})
		logger.err('res:%s', futil.toStr(res))
		]]
		---4.0 内容
		--[[
		local ok, record = pcall(self.request, self, h.enumEndPoint.ROOM_CHALLENGE_MG, 0, 
		h.enumKeyAction.REQ_MY_CHALLENGE_RECORD, 'requestMyChallengeRecord', {challengeId = v.challengeId})
		if ok then
			--logger.warn('myChallengeRecord,count:%s', futil.toStr(record))
			if record.challengeRecords then
				for k, v in pairs(record.challengeRecords) do
					logger.err('%s', futil.toStr(v))
				end
			end
		else
			logger.err('myChallengeRecord: failed')
		end
		local ok, record = pcall(self.request, self, h.enumEndPoint.ROOM_CHALLENGE_MG, 0, 
		h.enumKeyAction.REQ_MY_PASS_RECORD, 'requestMyPassRecord', {challengeId = v.challengeId})
		if ok then
			logger.warn('myPassRecord:%s', futil.toStr(record))
		else
			logger.err('myPassRecord: failed')
		end
		local ok,rv = pcall(self.request, self, h.enumEndPoint.ROOM_CHALLENGE_MG, 0, 
		h.enumKeyAction.REQ_PASS_RECORD, 'requestPassRecord', {challengeId = v.challengeId, startIndex=1, count=10, selectDate=nil})
		if not ok then
			logger.err('requestPassRecord failed')
		else
			if rv.passRecord and next(rv.passRecord) then
				logger.warn('passRecord count:%s', rv.passCount)
				for k, v in pairs(rv.passRecord) do
					logger.warn('%s', futil.toStr(v))
				end
			end
		end
		local ok, rv = pcall(self.request, self, h.enumEndPoint.ROOM_CHALLENGE_MG, 0,
		h.enumKeyAction.REQ_MY_CHALLENGE_INFO, 'requestMyChallengeInfo', {challengeId = v.challengeId})
		if not ok then
			logger.err('request my challenge info failed')
		else
			logger.warn('mychallenge info:%s', futil.toStr(rv))
		end

		local ok, rv = pcall(self.request, self, h.enumEndPoint.ROOM_CHALLENGE_MG, 0,
		h.enumKeyAction.REQ_MY_CHALLENGE_INFO, 'requestMyChallengeAward', {challengeId = v.challengeId})
		if not ok then
			logger.err('request my challenge award faield')
		else
			logger.warn('myChallengeAward:%s', futil.toStr(rv))
		end
		local ok,rv = pcall(self.request, self, h.enumEndPoint.ROOM_CHALLENGE_MG, 0, 
		h.enumKeyAction.REQ_PASS_RECORD, 'requestChallengeMaster', {challengeId = v.challengeId, startIndex=1, count=10, selectDate=nil})
		if not ok then
			logger.err('requestChallengeMaster failed')
		else
			logger.warn('challengeMaster:%s', futil.toStr(rv))
			if rv.passRecord and next(rv.passRecord) then
				for k, v in pairs(rv.passRecord) do
					logger.warn('challengeMaster %s', futil.toStr(v))
				end
			else
				logger.err('requestChallengeMaster return nil')
			end
		end
		]]
		---4.0 内容 end
		if self:challengeSignIn(v.challengeId) then
			return
		else
			logger.err('challengeSignIn failed')
		end
	end
end
function handler:kclub_test()
	local userInfo = self.auth.userInfo_
	logger.info("self:%s", futil.toStr(self.request))
	local ok, club_list = pcall(self.request, self, h.enumEndPoint.CLUB, 0, h.enumKeyAction.GET_CLUB_LIST,'getClubList', {type=0})

	logger.info('getClubList:%s,%s', ok, futil.toStr(club_list))
	if club_list and next(club_list) then
		if club_list.result == 0 and not next(club_list.clubs) then
			local cname = self.auth.userInfo_.nickName..':'..tostring(os.time())
			local rv = self:request(h.enumEndPoint.CLUB, 0, h.enumKeyAction.CREATE_CLUB, 'createClub',
				{clubName=cname, gameId=3004})
			logger.info("createClub rv:%s,%s", futil.toStr(rv), (h.GAME_ID.ZipaiForClub))
		end
		if next(club_list.clubs) then
			for k, v in pairs(club_list.clubs) do
				local req = {clubID=v.clubID, searchTime=futil.now_date(), searchKey=userInfo.nickName} 
				logger.info('req:%s', futil.toStr(req))
				local qrv = self:request(h.enumEndPoint.CLUB, 0, 
				h.enumKeyAction.QUERY_USER_RECORDS_BY_DAY, 'queryUserRecordsByDay',
				req)	
				logger.info('query rv:%s', futil.toStr(qrv))
			end
		end
	end
end
function handler:syncItems()
	local ok, rv = pcall(self.request, self, h.enumEndPoint.LOBBY_SERVER, 0,
		h.enumKeyAction.GET_ALL_ITEMS, 'synAllItems', {})
	if ok and rv then
		logger.debug('allItems:%s', futil.toStr(rv))
		local itemIds = {}
		self.items = {}
		for k, v in pairs(rv.items) do
			table.insert(itemIds, v.itemId)
			self.items[v.itemId] = v	
		end
		--synItemConf
		local ok, rv = pcall(self.request, self, h.enumEndPoint.LOBBY_SERVER, 0, 
			h.enumKeyAction.GET_ITEM_CONF, 'synItemConf', {itemIds=itemIds})
		if ok and rv then
			--logger.warn('itemConf:%s', futil.toStr(rv))
			for _, itemInfo in pairs(rv.itemConfs) do
				if self.items[itemInfo.itemId] then 
					for k, v in pairs(itemInfo) do
						self.items[itemInfo.itemId][k] = v
					end
				end
			end
			--logger.info('items:%s', futil.toStr(self.items))
		end
		--getPayData
		if self.items[2270] then
			local itemInfo = self.items[2270]
			ok, rv = pcall(self.request, self, h.enumEndPoint.LOBBY_SERVER, 0,
				h.enumKeyAction.GET_MALL_INFO, 'getMallInfo', {mallID=itemInfo.mallID})
			if ok and rv then
				logger.warn('mallInfo:%s', futil.toStr(rv))
			else
				logger.warn('mallInfo failed:%s', futil.toStr(rv))
			end
			----------------------------------
			ok, rv = pcall(self.request, self, h.enumEndPoint.MALL, 0,
				h.enumKeyAction.GET_PAY_DATA, 'getPayData', 
				{mallID=itemInfo.mallID, num=1, userGoodsID=itemInfo.userGoodsID,kind=3})
			if ok and rv then
				if rv.result ~= 0 then
					logger.warn('getPayData failed:%s,%s', futil.toStr(rv), futil.toStr(itemInfo))
				else
					logger.warn('getPayData success:%s', futil.toStr(rv))
				end
			else
				logger.err('getPayData error')
			end
		end
	else
		logger.err('synAllItems failed:%s', userInfo.userID)
	end
end
function handler:run()
    local ctx = self.ctx

	if not self.cl:closed() then
		authData = handler.auth
		self.auth = handler.auth
		userInfo = self.auth.userInfo_
		logger.info('auth data:%s', futil.toStr(authData))
        logger.info("TODO: 登陆成功,在这里运行你的第一行代码")
		self:syncItems()
		local ok, rv = pcall(self.request, self, h.enumEndPoint.LOBBY_SERVER, 0, 
			h.enumKeyAction.GET_PLAYER_STATUS, 'getPlayerStatus')
		if ok then
			logger.warn('playerStatus:%s', futil.toStr(rv))
			if rv.roomType == 8 then

				local ok, seasonInfo = self:getChallengeInfo() 
				if ok then
					self.challengeId = seasonInfo.challengeId
				end
				local _, data = pcall(self.request, self, h.enumEndPoint.ROOM_CHALLENGE, 0,
					h.enumKeyAction.COME_BACK_GAME, 'comeBackGame')
				if data and next(data) then
					logger.warn('comeBackGame:%s', futil.toStr(data))
					local ok, r = pcall(json.decode, data.strData)
					if ok then
						skynet.call('.client_service', 'lua', 'gaming', self.id, true)
						self.agentId = tonumber(r.selfID)
						self.gameStart = true
						self.isSignIn = true
						local agentID = r.agentID
						deskInfo.handCards = {}
						local tmpHandCards = {}
						deskInfo.deskID = r.desk_info.deskID
						for k, v in pairs(r.agents) do
							if agentID == v.agentID then
								deskInfo.handCards = v.handCards
								--[[
								for idx, num in pairs(v.handCards) do
									local n = num 
									while n > 0 do
										table.insert(deskInfo.handCards, idx)
										n = n - 1
									end
								end
								]]
							end
						end
						logger.info('reconnect handCards:%s', futil.toStr(deskInfo.handCards))
						logger.debug('agentId:%s', self.agentId)
					else
						logger.err('json decode failed')
					end
				end
			end
		else
			logger.warn('getPlayerStatus:faild')
		end
		self:test_win()
    end

	logger.info("handler.run end, id = %s", self.id)
--	self:exit()
end


skynet.init(function()
	const = require "const"
end)


return handler


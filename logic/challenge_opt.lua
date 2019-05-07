return {
    {
        startid = 700,
        endid = 700,
        handler = "challenge_handler",
        param = {
            appver = "0.0.0.0",		  -- 版本（可选参数）
			password = "123456",
			challengeId = "128",	  -- 挑战赛季ID
			keepSteps = "100",		  -- 保级概率(基数100)
			rechallengeOnFail = "100",-- 失败重复挑战概率(基数100) 
			rechallengeOnPass = "50", -- 通关重复挑战概率
			redeemCode = "666",       -- 金币不足时使用兑换码
        }
    },
}

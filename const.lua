local const = {}

const.heartbeat = {
	timeout = 30,
	send_interval = 10,
}

const.loglevel = {
    debug = 1,
    info  = 2,
    warn  = 3,
    err   = 4,
}
--key value must be same
const.pubsubChannel = {
	pub_test = "pub_test",
	WinChallengeConfigUpdate = "WinChallengeConfigUpdate",
	WinChallengeMgLock = "WinChallengeMgLock",
	client_service = 'client_service',
}
return const

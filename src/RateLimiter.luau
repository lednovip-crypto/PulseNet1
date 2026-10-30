--!strict
--!optimize 2
--[=[
    PulseNet - RateLimiter
    Token-bucket based rate limiter to protect Roblox servers from RemoteEvent spam.
]=]

export type RateLimiter = {
	Check: (self: RateLimiter, player: Player, cost: number?) -> boolean,
	Reset: (self: RateLimiter, player: Player) -> (),
	Destroy: (self: RateLimiter) -> (),
}

type Bucket = {
	tokens: number,
	lastRefill: number,
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(maxTokens: number, refillRatePerSecond: number): RateLimiter
	local self = setmetatable({
		_maxTokens = maxTokens,
		_refillRate = refillRatePerSecond,
		_buckets = {} :: { [Player]: Bucket },
	}, RateLimiter)
	return (self :: any) :: RateLimiter
end

function RateLimiter:Check(player: Player, cost: number?): boolean
	local tokenCost = cost or 1
	local now = os.clock()
	local bucket = self._buckets[player]

	if not bucket then
		bucket = {
			tokens = self._maxTokens - tokenCost,
			lastRefill = now,
		}
		self._buckets[player] = bucket
		return true
	end

	-- Refill tokens
	local elapsed = now - bucket.lastRefill
	bucket.tokens = math.min(self._maxTokens, bucket.tokens + (elapsed * self._refillRate))
	bucket.lastRefill = now

	if bucket.tokens >= tokenCost then
		bucket.tokens -= tokenCost
		return true
	end

	return false
end

function RateLimiter:Reset(player: Player)
	self._buckets[player] = nil
end

function RateLimiter:Destroy()
	table.clear(self._buckets)
end

return RateLimiter

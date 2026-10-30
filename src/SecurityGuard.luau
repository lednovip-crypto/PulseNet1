--!strict
--!optimize 2
--[=[
    PulseNet - SecurityGuard v1.1
    Production-grade Anti-Exploit, Payload Firewall, and DDoS Protection for Roblox servers.
]=]

local Players = game:GetService("Players")

export type SecurityConfig = {
	maxPayloadSizeBytes: number,
	strikeThreshold: number,
	strikeWindowSeconds: number,
	shadowBanDurationSeconds: number,
	dropMalformedNumbers: boolean,
}

local DEFAULT_CONFIG: SecurityConfig = {
	maxPayloadSizeBytes = 2048,     -- Максимум 2 КБ на пакет (защита от memory-bomb)
	strikeThreshold = 3,            -- 3 превышения лимита = бан пакетов
	strikeWindowSeconds = 5,        -- В окне 5 секунд
	shadowBanDurationSeconds = 30,  -- Теневой бан на 30 секунд
	dropMalformedNumbers = true,    -- Отсекать NaN и math.huge
}

type ViolatorState = {
	strikes: number,
	firstStrikeTime: number,
	bannedUntil: number,
}

local SecurityGuard = {}
SecurityGuard.__index = SecurityGuard

function SecurityGuard.new(config: SecurityConfig?)
	local self = setmetatable({
		_config = config or DEFAULT_CONFIG,
		_violators = {} :: { [Player]: ViolatorState },
	}, SecurityGuard)

	-- Очистка данных при выходе игрока
	Players.PlayerRemoving:Connect(function(player: Player)
		self._violators[player] = nil
	end)

	return self
end

-- Проверка: заблокирован ли игрок за спам
function SecurityGuard:IsPlayerBlocked(player: Player): boolean
	local state = self._violators[player]
	if not state then return false end

	local now = os.clock()
	if now < state.bannedUntil then
		return true -- Игрок в теневом бане, пакеты отбрасываются
	end

	return false
end

-- Регистрация подозрительного действия (превышение лимита пакетов)
function SecurityGuard:RecordViolation(player: Player): boolean
	local now = os.clock()
	local state = self._violators[player]

	if not state then
		state = {
			strikes = 1,
			firstStrikeTime = now,
			bannedUntil = 0,
		}
		self._violators[player] = state
		return false
	end

	-- Сброс окна страйков по истечении времени
	if now - state.firstStrikeTime > self._config.strikeWindowSeconds then
		state.strikes = 1
		state.firstStrikeTime = now
		return false
	end

	state.strikes += 1

	-- Если порог превышен — включаем теневой бан
	if state.strikes >= self._config.strikeThreshold then
		state.bannedUntil = now + self._config.shadowBanDurationSeconds
		warn(string.format("[PulseNet Security] SHADOW-BAN activated for player %s for %d seconds (Remote Spam)", 
			player.Name, self._config.shadowBanDurationSeconds))
		return true
	end

	return false
end

-- Проверка и очистка вредоносных данных (NaN, Infinity, гигантские строки)
function SecurityGuard:ValidateData(data: any): boolean
	local dataType = type(data)

	if dataType == "number" then
		-- Защита от NaN и math.huge
		if self._config.dropMalformedNumbers then
			if data ~= data or data == math.huge or data == -math.huge then
				return false
			end
		end
		return true

	elseif dataType == "string" then
		-- Защита от строк гигантского размера
		if #data > self._config.maxPayloadSizeBytes then
			return false
		end
		return true

	elseif dataType == "table" then
		local count = 0
		for k, v in pairs(data) do
			count += 1
			if count > 100 then return false end -- Защита от таблиц на тысячи ключей
			if not self:ValidateData(v) then return false end
		end
		return true
	end

	return true
end

function SecurityGuard:Destroy()
	table.clear(self._violators)
end

return SecurityGuard

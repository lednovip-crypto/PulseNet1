--!strict
--!optimize 2
--[=[
    PulseNet Server
    Manages batched RemoteEvents, rate limiting, and network synchronization on the Roblox Server.
]=]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Signal = require(script.Parent.Signal)
local RateLimiter = require(script.Parent.RateLimiter)

export type Middleware = (player: Player, channel: string, data: any) -> boolean

local Server = {}
Server.__index = Server

function Server.new(parentFolder: Instance?)
	local folder = parentFolder or script.Parent:FindFirstChild("_network")
	if not folder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "_network"
		newFolder.Parent = script.Parent
		folder = newFolder
	end

	-- Reliable Remote
	local reliableRemote = folder:FindFirstChild("ReliableBatch") :: RemoteEvent?
	if not reliableRemote then
		local remote = Instance.new("RemoteEvent")
		remote.Name = "ReliableBatch"
		remote.Parent = folder
		reliableRemote = remote
	end

	-- Unreliable Remote
	local unreliableRemote = folder:FindFirstChild("UnreliableBatch") :: UnreliableRemoteEvent?
	if not unreliableRemote then
		local remote = Instance.new("UnreliableRemoteEvent")
		remote.Name = "UnreliableBatch"
		remote.Parent = folder
		unreliableRemote = remote
	end

	local self = setmetatable({
		_folder = folder,
		_reliableRemote = reliableRemote,
		_unreliableRemote = unreliableRemote,
		_channels = {} :: { [string]: Signal.Signal<Player, any> },
		_outgoingReliable = {} :: { [Player]: { { channel: string, data: any } } },
		_outgoingUnreliable = {} :: { [Player]: { { channel: string, data: any } } },
		_rateLimiter = RateLimiter.new(60, 30), -- 60 burst, 30/sec
		_middlewares = {} :: { Middleware },
		_heartbeatConn = nil :: RBXScriptConnection?,
	}, Server)

	self:_initListeners()
	return self
end

function Server:_initListeners()
	self._reliableRemote.OnServerEvent:Connect(function(player: Player, batch: any)
		self:_handleIncoming(player, batch)
	end)

	self._unreliableRemote.OnServerEvent:Connect(function(player: Player, batch: any)
		self:_handleIncoming(player, batch)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self._outgoingReliable[player] = nil
		self._outgoingUnreliable[player] = nil
		self._rateLimiter:Reset(player)
	end)

	-- Flush batches every Heartbeat
	self._heartbeatConn = RunService.Heartbeat:Connect(function()
		self:_flush()
	end)
end

function Server:_handleIncoming(player: Player, batch: any)
	if type(batch) ~= "table" then return end

	-- Check rate limit
	if not self._rateLimiter:Check(player, #batch) then
		warn(string.format("[PulseNet] Player %s exceeded packet rate limit!", player.Name))
		return
	end

	for _, packet in ipairs(batch) do
		if type(packet) == "table" and type(packet.channel) == "string" then
			local channel = packet.channel
			local data = packet.data

			-- Middlewares
			local allowed = true
			for _, middleware in ipairs(self._middlewares) do
				if not middleware(player, channel, data) then
					allowed = false
					break
				end
			end

			if allowed and self._channels[channel] then
				self._channels[channel]:Fire(player, data)
			end
		end
	end
end

function Server:Use(middleware: Middleware)
	table.insert(self._middlewares, middleware)
end

function Server:On(channel: string, callback: (player: Player, data: any) -> ()): Signal.Connection
	if not self._channels[channel] then
		self._channels[channel] = Signal.new()
	end
	return self._channels[channel]:Connect(callback)
end

function Server:Fire(player: Player, channel: string, data: any, unreliable: boolean?)
	local targetTable = if unreliable then self._outgoingUnreliable else self._outgoingReliable
	if not targetTable[player] then
		targetTable[player] = {}
	end
	table.insert(targetTable[player], { channel = channel, data = data })
end

function Server:FireAll(channel: string, data: any, unreliable: boolean?)
	for _, player in ipairs(Players:GetPlayers()) do
		self:Fire(player, channel, data, unreliable)
	end
end

function Server:FireExcept(exceptPlayer: Player, channel: string, data: any, unreliable: boolean?)
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= exceptPlayer then
			self:Fire(player, channel, data, unreliable)
		end
	end
end

function Server:_flush()
	-- Flush reliable batches
	for player, batch in pairs(self._outgoingReliable) do
		if #batch > 0 then
			self._reliableRemote:FireClient(player, batch)
			table.clear(batch)
		end
	end

	-- Flush unreliable batches
	for player, batch in pairs(self._outgoingUnreliable) do
		if #batch > 0 then
			self._unreliableRemote:FireClient(player, batch)
			table.clear(batch)
		end
	end
end

function Server:Destroy()
	if self._heartbeatConn then
		self._heartbeatConn:Disconnect()
		self._heartbeatConn = nil
	end
	self._rateLimiter:Destroy()
	table.clear(self._channels)
	table.clear(self._outgoingReliable)
	table.clear(self._outgoingUnreliable)
end

return Server

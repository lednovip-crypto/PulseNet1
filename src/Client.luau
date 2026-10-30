--!strict
--!optimize 2
--[=[
    PulseNet Client
    Batched remote listener and dispatcher on the Roblox Client.
]=]

local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Signal)

local Client = {}
Client.__index = Client

function Client.new(parentFolder: Instance?)
	local folder = parentFolder or script.Parent:WaitForChild("_network", 10) :: Instance?
	if not folder then
		error("[PulseNet] Failed to find _network folder in replicated structure.")
	end

	local reliableRemote = folder:WaitForChild("ReliableBatch") :: RemoteEvent
	local unreliableRemote = folder:WaitForChild("UnreliableBatch") :: UnreliableRemoteEvent

	local self = setmetatable({
		_folder = folder,
		_reliableRemote = reliableRemote,
		_unreliableRemote = unreliableRemote,
		_channels = {} :: { [string]: Signal.Signal<any> },
		_outgoingReliable = {} :: { { channel: string, data: any } },
		_outgoingUnreliable = {} :: { { channel: string, data: any } },
		_heartbeatConn = nil :: RBXScriptConnection?,
	}, Client)

	self:_initListeners()
	return self
end

function Client:_initListeners()
	self._reliableRemote.OnClientEvent:Connect(function(batch: any)
		self:_handleIncoming(batch)
	end)

	self._unreliableRemote.OnClientEvent:Connect(function(batch: any)
		self:_handleIncoming(batch)
	end)

	self._heartbeatConn = RunService.Heartbeat:Connect(function()
		self:_flush()
	end)
end

function Client:_handleIncoming(batch: any)
	if type(batch) ~= "table" then return end

	for _, packet in ipairs(batch) do
		if type(packet) == "table" and type(packet.channel) == "string" then
			local channel = packet.channel
			local data = packet.data
			if self._channels[channel] then
				self._channels[channel]:Fire(data)
			end
		end
	end
end

function Client:On(channel: string, callback: (data: any) -> ()): Signal.Connection
	if not self._channels[channel] then
		self._channels[channel] = Signal.new()
	end
	return self._channels[channel]:Connect(callback)
end

function Client:Fire(channel: string, data: any, unreliable: boolean?)
	local targetTable = if unreliable then self._outgoingUnreliable else self._outgoingReliable
	table.insert(targetTable, { channel = channel, data = data })
end

function Client:_flush()
	if #self._outgoingReliable > 0 then
		self._reliableRemote:FireServer(self._outgoingReliable)
		table.clear(self._outgoingReliable)
	end

	if #self._outgoingUnreliable > 0 then
		self._unreliableRemote:FireServer(self._outgoingUnreliable)
		table.clear(self._outgoingUnreliable)
	end
end

function Client:Destroy()
	if self._heartbeatConn then
		self._heartbeatConn:Disconnect()
		self._heartbeatConn = nil
	end
	table.clear(self._channels)
	table.clear(self._outgoingReliable)
	table.clear(self._outgoingUnreliable)
end

return Client

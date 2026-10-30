--!strict
--!optimize 2
--[=[
    PulseNet v1.0.0
    A high-performance batched, buffer-accelerated networking library for Roblox.
    Licensed under MIT.
]=]

local RunService = game:GetService("RunService")

local Signal = require(script.Signal)
local Serializer = require(script.Serializer)
local RateLimiter = require(script.RateLimiter)
local Server = require(script.Server)
local Client = require(script.Client)

export type Signal<T...> = Signal.Signal<T...>
export type Connection = Signal.Connection
export type RateLimiter = RateLimiter.RateLimiter

local PulseNet = {
	Serializer = Serializer,
	Signal = Signal,
	RateLimiter = RateLimiter,
}

if RunService:IsServer() then
	PulseNet.Server = Server.new()
elseif RunService:IsClient() then
	PulseNet.Client = Client.new()
end

return PulseNet

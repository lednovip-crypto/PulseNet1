--!strict
--!optimize 2
--[=[
    PulseNet - Fast Event Signal
    High-performance, lightweight connection/signal handler in Luau.
]=]

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	Destroy: (self: Signal<T...>) -> (),
}

type Node = {
	callback: (...any) -> (),
	next: Node?,
	prev: Node?,
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({
		_head = nil :: Node?,
		_tail = nil :: Node?,
	}, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal:Connect(callback: (...any) -> ()): Connection
	local node: Node = {
		callback = callback,
		next = nil,
		prev = self._tail,
	}

	if self._tail then
		self._tail.next = node
		self._tail = node
	else
		self._head = node
		self._tail = node
	end

	local connection: Connection
	connection = {
		Connected = true,
		Disconnect = function()
			if not connection.Connected then return end
			connection.Connected = false

			if node.prev then
				node.prev.next = node.next
			else
				self._head = node.next
			end

			if node.next then
				node.next.prev = node.prev
			else
				self._tail = node.prev
			end
		end,
	}

	return connection
end

function Signal:Once(callback: (...any) -> ()): Connection
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

function Signal:Fire(...: any)
	local current = self._head
	while current do
		task.spawn(current.callback, ...)
		current = current.next
	end
end

function Signal:Wait(): ...any
	local thread = coroutine.running()
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:Destroy()
	self._head = nil
	self._tail = nil
end

return Signal

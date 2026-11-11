-- Minimal signal (connect / fire / disconnect).

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handlers = self.handlers
	table.insert(handlers, fn)
	return {
		Disconnect = function()
			for i, h in ipairs(handlers) do
				if h == fn then
					table.remove(handlers, i)
					break
				end
			end
		end,
	}
end

function Signal:Fire(...)
	for _, fn in ipairs(self.handlers) do
		task.spawn(fn, ...)
	end
end

return Signal

--[[
     Animation for Skeletal animation
--]]

local Animation = {}
Animation.__index = Animation
Animation.__call  = function (t, ...) t.new(...) end

function Animation.new(...)
	local a = {}

	return setmetatable(a, {})
end

return Animation
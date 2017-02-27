--[[
     Actor for Skeletal animation
--]]

local Actor = {}
Actor.__index = Actor
Actor.__call  = function (t, ...) t.new(...) end

function Actor.new(...)
	local a = {}

	return setmetatable(a, {})
end

return Actor
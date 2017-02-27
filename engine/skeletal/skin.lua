--[[
     Skin for Skeletal animation
--]]

local Skin = {}
Skin.__index = Skin
Skin.__call  = function (t, ...) t.new(...) end

function Skin.new(...)
	local a = {}

	return setmetatable(a, {})
end

return Skin
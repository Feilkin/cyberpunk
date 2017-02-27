--[[
     Skeleton for Skeletal animation
--]]

-- someone told me this is super fast??
local sin, cos = math.sin, math.cos

-- bones, too lazy to make a file for these
local Bone = {}
Bone.__index = Bone
Bone.__call  = function (t, ...) t.new(...) end

function Bone.new(position, length, rotation)
	local b = {
		position = position,
		length   = length,
		rotation = rotation
	}

	return setmetatable(b, Bone)
end

function Bone.clone(bone)
	return Bone.new(bone.position, bone.length, bone.rotation)
end

local Skeleton = {}
Skeleton.__index = Skeleton
Skeleton.__call  = function (t, ...) t.new(...) end

function Skeleton.new(...)
	local a = {
		bones = {} -- name -> bone mapping, because skeletons have bones
	}

	return setmetatable(a, {})
end

function Skeleton:setBones(bones)
	local a = {}
	for k, v in pairs(bones) do
		a[k] = v
	end

	self.bones = a
end

-- this function is mostly used for debugging
function Skeleton:draw()
	for i, b in ipairs(self.bones) do
		local x1, y1 = b.position.x, b.position.y
		local x2, y2 = x1 + cos(b.rotation) * b.length,
		               y1 + sin(b.rotation) * b.length

		love.graphics.circle('fill',
			x1, y1,
			10 + b.length / 10)
		love.graphics.line(x1, y1, x2, y2)
	end
end

return Skeleton
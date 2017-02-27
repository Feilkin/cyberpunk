--[[
	#Skeletal Animation Framework for Löve

	I modeled this after DragonBone (5.0) export format,
	but I think it should be easy to implement for other
	formats too.

	## Structure or wtf this is called
	    Actor
	    	- Skeleton
	    		- Bones
	    	- Animations
	    		- keyframes for Bones
	    	-Skin
	    		- Visuals that are attached to bones

--]]
local cwd = (...):gsub('%.init$', '') .. '.'

local skeletal = {
	Actor     = require (cwd .. 'actor'),
	Skeleton  = require (cwd .. 'skeleton'),
	Animation = require (cwd .. 'animation'),
	Skin      = require (cwd .. 'skin'),
}
skeletal.__index = skeletal
skeletal.__call = function(t, ...) t.Actor.new(...) end

return setmetatable(skeletal, {})
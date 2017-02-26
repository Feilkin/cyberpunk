--[[
--   Feikkis another game engine thing
--]]

engine = {} -- global because we have a time limit

local cwd = (...):gsub('%.init$', '') .. '.' -- OK i stole this part from STI

-- third party libraries
-- nuklear is a bit tricky
old_cpath = package.cpath
package.cpath = './engine/thirdparty/?.so'
engine.ui        = require('nuklear')        -- https://github.com/keharriso/love-nuklear
package.cpath = old_cpath
engine.gamestate = require(cwd .. 'thirdparty.hump.gamestate') -- https://github.com/vrld/hump
engine.timer     = require(cwd .. 'thirdparty.hump.timer')     -- https://github.com/vrld/hump
engine.vector    = require(cwd .. 'thirdparty.hump.vector')    -- https://github.com/vrld/hump
engine.signal    = require(cwd .. 'thirdparty.hump.signal')    -- https://github.com/vrld/hump
engine.camera    = require(cwd .. 'thirdparty.hump.camera')    -- https://github.com/vrld/hump
engine.map       = require(cwd .. 'thirdparty.sti')            -- https://github.com/karai17/Simple-Tiled-Implementation
engine.physics   = require(cwd .. 'thirdparty.bump')           -- https://github.com/kikito/bump.lua
engine.ecs       = require(cwd .. 'thirdparty.tiny')           -- https://github.com/bakpakin/tiny-ecs

-- the game loader
engine.load = require(cwd .. 'loader')

-- skeletal animations
engine.skeleton = require(cwd .. 'skeleton')

return engine
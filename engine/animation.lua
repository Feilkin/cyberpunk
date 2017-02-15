--[[
     Loader for DargonBones animations (version 5.0 I think?)
--]]

local json = require 'json'
local inspect = require 'inspect'

local Animation = {}

function Animation.new(filename)
    assert(filename, 'missing argument filename')

    local filedata = love.filesystem.read(filename)
    local data = json.decode(filedata)
    local t = {}

    print(inspect(data))

    return setmetatable({}, Animation)
end

return setmetatable({}, Animation)
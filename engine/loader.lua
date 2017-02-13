--[[

--]]

assert(engine, "'engine' not found, make sure you have required it")

local loader = {}

function loader.load_game(identifier)
    local game = require(identifier)
    engine.game = game

    engine.gamestate.registerEvents()
    engine.gamestate.switch(require('game.gamestates.' .. game.entrypoint))
end

setmetatable(loader, {
    __call = function(t, ...) t.load_game(...) end
})

return loader
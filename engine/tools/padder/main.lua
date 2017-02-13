--[[
     Some tile padder
--]]

local preview

function love.load()
    local tileset = love.graphics.newImage('tileset.png')
    local padding = 1
    local tilewidth = 16
    local tileheight = 16

    local iw, ih = tileset:getDimensions()
    local columns = math.floor(iw / (tilewidth + padding))
    local rows = math.floor(ih / (tileheight + padding))

    local quads = {}

    for r = 1, rows do
        for c = 1, columns do
            local x, y = (c - 1) * (tilewidth + padding), (r - 1) * (tileheight + padding)
            table.insert(quads, love.graphics.newQuad(x, y, tilewidth + padding, tileheight + padding, iw, ih))
        end
    end

    local canvas = love.graphics.newCanvas(iw, ih)
    love.graphics.setCanvas(canvas)

    for r = 1, rows do
        for c = 1, columns do
            local x, y = (c - 1) * (tilewidth + padding), (r - 1) * (tileheight + padding)
            local i = (r - 1) * columns + c
            local q = quads[i]
            love.graphics.draw(tileset, q, x + 1, y)
            love.graphics.draw(tileset, q, x, y + 1)
            love.graphics.draw(tileset, q, x, y)
        end
    end
    love.graphics.setCanvas()
    local tilesetData = canvas:newImageData()
    tilesetData:encode('png', 'tilesetPadded.png')
    preview = canvas
end

function love.draw()
    love.graphics.draw(preview, 0, 0)
end
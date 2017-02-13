
local map, navmesh

package.path = '../../thirdparty/?.lua;../../thirdparty/?/init.lua'

local sti = require 'sti'
local inspect = require 'inspect'

local min, max = math.min, math.max
local tinsert  = table.insert

function love.load()
    map = sti('game/resources/maps/offices.lua')
    navmesh = {
        -- the 'root' object
        {
            x = 0,
            y = 0,
            width = map.width * map.tilewidth,
            height = map.height * map.tileheight,
        }
    }

    for _, obj in ipairs(map.layers['collisions'].objects) do
        local to_remove, to_add = {}, {}

        for _, nav in ipairs(navmesh) do
            -- check if they collide
            if (obj.x < nav.x + nav.width)  and
               (obj.x + obj.width > nav.x)  and
               (obj.y < nav.y + nav.height) and
               (obj.y + obj.height > nav.y) then
                --
                -- x1 _______ y1
                --   |       |
                --   |       |
                --   |_______|
                -- x2         y2
                --
                local x1, x2 = max(obj.x, nav.x), min(obj.x + obj.width, nav.x + nav.width)
                local y1, y2 = max(obj.y, nav.y), min(obj.y + obj.height, nav.y + nav.height)
                local nx, ny = nav.x, nav.y
                local mx, my = nav.x + nav.width, nav.y + nav.height

                assert((x1 < x2) and (y1 < y2), 'i suck at math' )

                -- cut the navmesh into pieces
                local new_meshes = {}

                -- nx, ny _______________________
                --       |   1   |   2   |   3   |
                --       |       |       |       |
                --       |_______ _______ _______|
                --       |   4   |(x1,y1)|   5   |
                --       |       |       |       |
                --       |_______|_______|_______|
                --       |   6   |   7   |   8   |
                --       |       |       |       |
                --       |_______|_______|_______|

                if (x1 > nx) and (y1 > ny) then
                    -- block 1
                    -- nx, ny _____ x1, ny
                    --       |     |
                    --       |_____|
                    -- nx, y1       x1, y1

                    tinsert(new_meshes, {
                        x = nx,
                        y = ny,
                        width = x1 - nx,
                        height = y1 - ny
                    })
                end
                if (y1 > ny) then
                    -- block 2
                    -- x1, ny _____ x2, ny
                    --       |     |
                    --       |_____|
                    -- x1, y1       x2, y1

                    tinsert(new_meshes, {
                        x = x1,
                        y = ny,
                        width = x2 - x1,
                        height = y1 - ny
                    })
                end
                if (x2 < mx) and (y1 > ny) then
                    -- block 3
                    -- x2, ny _____ mx, ny
                    --       |     |
                    --       |_____|
                    -- x2, y1       mx, y1

                    tinsert(new_meshes, {
                        x = x2,
                        y = ny,
                        width = mx - x2,
                        height = y1 - ny
                    })
                end

                if (x1 > nx) then
                    -- block 4
                    -- nx, y1 _____ x1, y1
                    --       |     |
                    --       |_____|
                    -- nx, y2       x1, y2
                    
                    tinsert(new_meshes, {
                        x = nx,
                        y = y1,
                        width = x1 - nx,
                        height = y2 - y1
                    })
                end
                if (x2 < mx) then
                    -- block 5
                    -- x2, y1 _____ mx, y1
                    --       |     |
                    --       |_____|
                    -- x2, y2       mx, y2
                    
                    tinsert(new_meshes, {
                        x = x2,
                        y = y1,
                        width = mx - x2,
                        height = y2 - y1
                    })
                end


                if (x1 > nx) and (y2 < my) then
                    -- block 6
                    -- nx, y2 _____ x1, y2
                    --       |     |
                    --       |_____|
                    -- nx, my       x1, my
                    
                    tinsert(new_meshes, {
                        x = nx,
                        y = y2,
                        width = x1 - nx,
                        height = my - y2
                    })
                end
                if (y2 < my) then
                    -- block 7
                    -- x1, y2 _____ x2, y2
                    --       |     |
                    --       |_____|
                    -- x1, my       x2, my
                    
                    tinsert(new_meshes, {
                        x = x1,
                        y = y2,
                        width = x2 - x1,
                        height = my - y2
                    })
                end
                if (x2 < mx) and (y2 < my) then
                    -- block 8
                    -- x2, y2 _____ mx, y2
                    --       |     |
                    --       |_____|
                    -- x2, my       mx, my
                    
                    tinsert(new_meshes, {
                        x = x2,
                        y = y2,
                        width = mx - x2,
                        height = my - y2
                    })
                end

                for _, m in ipairs(new_meshes) do
                    tinsert(to_add, m)
                end
                to_remove[nav] = true
           end
        end

        local t = {}
        for _, m in ipairs(navmesh) do
            if not to_remove[m] then
                tinsert(t, m)
            end
        end
        for _, m in ipairs(to_add) do
            tinsert(t, m)
        end

        navmesh = t
    end

    local lookup = {}
    for _, m in ipairs(navmesh) do
        local to_remove = {}

        if not lookup[m] then
            lookup[m] = {}
        end

        if not m.properties then
            m.properties = {
                connectsTo = {}
            }
        end

        for _, o in ipairs(navmesh) do
            if not lookup[o] then
                lookup[o] = {}
            end

            if (m ~= o) and (not lookup[m][o]) then
                if not o.properties then
                    o.properties = {
                        connectsTo = {}
                    }
                end

                if (m.x <= o.x + o.width)  and
                   (m.x + m.width >= o.x)  and
                   (m.y <= o.y + o.height) and
                   (m.y + m.height >= o.y) then
                    tinsert(m.properties.connectsTo, o)
                    tinsert(o.properties.connectsTo, m)
                    lookup[m][o] = true
                    lookup[o][m] = true
               end
            end
        end

        if #m.properties.connectsTo == 0 then
            to_remove[m] = true
        end

        local t = {}
        for _, m in ipairs(navmesh) do
            if not to_remove[m] then
                tinsert(t, m)
            end
        end
        navmesh = t
    end

    -- generate ID's
    local i = map.nextobjectid
    for _, m in ipairs(navmesh) do
        m.id = i
        m.shape = 'rectangle'
        m.rotation = 0
        m.type = 'navmesh'
        i = i + 1
    end
    map.nextobjectid = i

    -- connectsTo obj -> id
    for _, m in ipairs(navmesh) do
        local t = {}
        for _, o in ipairs(m.properties.connectsTo) do
            tinsert(t, o.id)
        end
        m.properties.connectsTo = table.concat(t, ',')
    end

    print(inspect(navmesh))

    -- patch it to the map
    local layer = map.layers['navmesh']

    layer.objects = navmesh
    map:setObjectData(layer)
    map:setObjectCoordinates(layer)

end

function love.draw()
    love.graphics.translate(-1120, 0)
    map:draw()

    for _, m in ipairs(navmesh) do
        love.graphics.setColor(255, 0, 255, 128)
        love.graphics.rectangle('fill', m.x, m.y, m.width, m.height)
        love.graphics.setColor(255, 255, 255, 255)

        local x1, y1 = m.x + m.width/2, m.y + m.height/2
        for oid in string.gmatch(m.properties.connectsTo, '[0-9]+') do
            local o = map.objects[tonumber(oid)]
            local x2, y2 = o.x + o.width/2, o.y + o.height/2
            love.graphics.line(x1, y1, x2, y2)
        end
    end
end
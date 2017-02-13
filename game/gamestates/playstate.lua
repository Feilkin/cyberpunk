--[[
     Where the magick happens
--]]

assert(engine, "'engine' not found, make sure you have required it")

local state = {}

local world, ecs, map, camera, player
local font

local processingSystems = engine.ecs.rejectAll('renderer')
local renderingSystems = engine.ecs.requireAll('renderer')

local cursorCrosshair, cursorInvalid
local bloodParticle, ricochetParticle

local splatterCanvas

function state:enter()
    love.graphics.setDefaultFilter('nearest', 'nearest', 4)

    font = love.graphics.newFont('game/resources/font.bdf', 11)
    love.graphics.setFont(font)

    cursorCrosshair = love.mouse.newCursor('game/resources/cursor_crosshair.png', 8, 8)
    cursorInvalid = love.mouse.newCursor('game/resources/cursor_invalid.png', 8, 8)
    love.mouse.setCursor(cursorCrosshair)

    bloodParticle = love.graphics.newImage('game/resources/blood_particle.png')
    ricochetParticle = love.graphics.newImage('game/resources/ricochet_particle.png')

    world = engine.physics.newWorld()
    map = engine.map('game/resources/maps/offices.lua', { 'bump' })
    map:bump_init(world)

    splatterCanvas = love.graphics.newCanvas(map.width * map.tilewidth, map.height * map.tileheight)

    -- lets monkey patch because karai is a fagget

    function map:findObject(layername, name)
        local o = self.layers[layername].objects

        for _, v in ipairs(o) do
            if v.name == name then return v end
        end
    end

    -- pathfinding monkey patch

    function map:prepareNavMesh()
        local layer = assert(self.layers['navmesh'], 'Map does not contain navmesh layer!')

        for _, obj in pairs(layer.objects) do
            assert((obj.type == 'navmesh') and obj.properties.connectsTo, 'Invalid navmesh!')

            local t = {}
            if obj.properties.connectsTo ~= '' then
                for id in string.gmatch(obj.properties.connectsTo, '[0-9]+') do
                    id = tonumber(id, 10)
                    local target = self.objects[id]
                    table.insert(t, target)
                end
            end
            obj.properties.connectsTo = t
        end
    end

    function map:drawNavMesh()
        local layer = assert(self.layers['navmesh'], 'Map does not contain navmesh layer!')
        for _, obj in pairs(layer.objects) do
            assert((obj.type == 'navmesh') and obj.properties.connectsTo, 'Invalid navmesh!')
            local x1, y1 = obj.x + obj.width / 2, obj.y + obj.height / 2

            for _, target in ipairs(obj.properties.connectsTo) do
                local x2, y2 = target.x + target.width / 2, target.y + target.height / 2
                love.graphics.line(x1, y1, x2, y2)
            end
        end
    end

    function map:findMeshAt(x, y)
        local layer = assert(self.layers['navmesh'], 'Map does not contain navmesh layer!')
        for _, obj in pairs(layer.objects) do
            if obj.x <= x and obj.x + obj.width  >= x and
               obj.y <= y and obj.y + obj.height >= y then
                return obj
            end
        end
    end

    -- returns a list of {x, y} points the entity can walk along to get to goal
    function map:findPath(e, x1, y1, x2, y2)
        local starting_mesh = map:findMeshAt(x1, y1)
        local goal_mesh     = map:findMeshAt(x2, y2)

        if starting_mesh ~= goal_mesh then
            local frontier, came_from = {starting_mesh}, {}

            while #frontier > 0 do
                local current = table.remove(frontier, 1)
                if not current then break end

                for _, other in ipairs(current.properties.connectsTo) do
                    if not came_from[other] then
                        table.insert(frontier, other)
                        came_from[other] = current
                    end
                end
            end

            local current = goal_mesh
            local meshpath = {current}

            while current ~= starting_mesh do
                current = came_from[current]
                if not current then return nil end
                table.insert(meshpath, current)
            end

            -- reverse the meshpath
            local meshpath_reversed = {}
            for i = #meshpath, 1, -1 do
                table.insert(meshpath_reversed, meshpath[i])
            end
            meshpath = meshpath_reversed

            local path = {}
            local padding = 1

            for i = 1, #meshpath do
                local a, b = meshpath[i], meshpath[i + 1]

                if not b then break end

                -- find the axis the nodes connect in
                if a.x == b.x + b.width then
                    local edgeStartY = math.max(a.y, b.y)
                    local edgeEndY   = math.min(a.y + a.height, b.y + b.height)
                    local edgeX      = a.x

                    edgeStartY = edgeStartY + padding
                    edgeEndY = edgeEndY - e.height - padding

                    local edgeY = math.max(math.min(edgeEndY, e.y), edgeStartY)

                    table.insert(path, {x = edgeX, y = edgeY})
                    table.insert(path, {x = edgeX - e.width, y = edgeY})
                elseif a.x + a.width == b.x then
                    local edgeStartY = math.max(a.y, b.y)
                    local edgeEndY   = math.min(a.y + a.height, b.y + b.height)
                    local edgeX      = b.x - e.width

                    edgeStartY = edgeStartY + padding
                    edgeEndY = edgeEndY - e.height - padding

                    local edgeY = math.max(math.min(edgeEndY, e.x), edgeStartY)

                    table.insert(path, {x = edgeX, y = edgeY})
                    table.insert(path, {x = edgeX + e.width, y = edgeY})
                elseif a.y == b.y + b.height then
                    local edgeStartX = math.max(a.x, b.x)
                    local edgeEndX   = math.min(a.x + a.width, b.x + b.width)
                    local edgeY      = a.y

                    edgeStartX = edgeStartX + padding
                    edgeEndX = edgeEndX - e.width - padding

                    local edgeX = math.max(math.min(edgeEndX, e.x), edgeStartX)

                    table.insert(path, {x = edgeX, y = edgeY})
                    table.insert(path, {x = edgeX, y = edgeY - e.height})
                elseif a.y + a.height == b.y then
                    local edgeStartX = math.max(a.x, b.x)
                    local edgeEndX   = math.min(a.x + a.width, b.x + b.width)
                    local edgeY      = b.y - e.height

                    edgeStartX = edgeStartX + padding
                    edgeEndX = edgeEndX - e.width - padding

                    local edgeX = math.max(math.min(edgeEndX, e.x), edgeStartX)

                    table.insert(path, {x = edgeX, y = edgeY})
                    table.insert(path, {x = edgeX, y = edgeY + e.height})
                end
            end

            table.insert(path, {x = x2, y = y2})
            return path
        else
            -- both points are inside the same mesh
            return {{x = x2, y = y2}}
        end
    end

    function map:raycastVision(e)
        -- cast rays to each wall corner from where the entity stands
        -- use bump because we are lazy faggets
        local endpoints, vision_segments = {}, {}
        local x1, y1 = e.x + e.width/2, e.y + e.height/2

        --[[
        for _, obj in ipairs(self.layers['collisions'].objects) do
            table.insert(endpoints, {obj.x, obj.y})
            table.insert(endpoints, {obj.x + obj.width, obj.y})
            table.insert(endpoints, {obj.x + obj.width, obj.y + obj.height})
            table.insert(endpoints, {obj.x, obj.y + obj.height})
        end
        --]]

        local steps = 180
        local view_distance = e.viewDistance or 300
        for i = 1, steps do
            local a = math.pi * 2 / steps * i
            local x2 = math.floor(x1 + math.sin(a) * view_distance)
            local y2 = math.floor(y1 + math.cos(a) * view_distance)
            table.insert(endpoints, {x2, y2})
        end

        local function filter(c)
            if c == e then return false end
            if c.type then
                if c.type == 'enemy' then return false end
            end
            if c.object then
                if c.object.type == 'door' then
                    if c.object.properties.open == true then return false end
                end

                if c.object.properties.objectHeight and e.eyeLevel then
                    if c.object.properties.objectHeight < e.eyeLevel then return false end
                end
            end

            return true
        end

        local function sortByAngle(a, b)
            return a[3] < b[3]
        end

        for _, p in ipairs(endpoints) do
            local x2, y2 = p[1], p[2]
            local items, len = world:querySegmentWithCoords(x1, y1, x2, y2, filter)
            if len == 0 then
                local angle = math.atan2((x1-x2),(y1-y2))
                table.insert(vision_segments, {x2, y2, angle})
            else
                x2, y2 = items[1].x1, items[1].y1
                local angle = math.atan2((x1-x2),(y1-y2))
                table.insert(vision_segments, {x2, y2, angle})
            end
        end

        table.sort(vision_segments, sortByAngle)

        return vision_segments
    end

    -- prepare navmesh
    map:prepareNavMesh()

    -- find the spawn from the map
    spawn = map:findObject('objects', 'playerSpawn')
    assert(spawn, 'Could not find spawn!')

    player = {
        image = love.graphics.newImage('game/resources/noob.png'),
        x = spawn.x,
        y = spawn.y,
        width = 14,
        height = 10,
        offsetY = -5,
        viewDistance = 320,
        eyeLevelStanding = 160,
        eyeLevelCrouching = 80,
        eyeLevel = 160,
        health = 30,
        maxHealth = 30,
        gun = {
            cooldown = 0,
            mag = 13,
            firerate = 500,
            magsize  = 13,
            reload_time = 2,
            bullet_speed = 600,
        },
        name = 'player'
    }

    function player.drawVision(fuzzy)
        if player.vision and (#player.vision > 0) then
            for i = 1, #player.vision do
                local a, b = player.vision[i], player.vision[i + 1]
                if not b then b = player.vision[1] end
                local x1, y1 = math.floor(player.x + player.width/2),
                               math.floor(player.y + player.height/2)
                local x2, y2, x3, y3 = math.floor(a[1]), math.floor(a[2]),
                                       math.floor(b[1]), math.floor(b[2])
                
                fuzzy = fuzzy or  12
                x2 = math.floor(x2 - math.sin(a[3]) * fuzzy)
                y2 = math.floor(y2 - math.cos(a[3]) * fuzzy)
                x3 = math.floor(x3 - math.sin(b[3]) * fuzzy)
                y3 = math.floor(y3 - math.cos(b[3]) * fuzzy)
                --]]

                love.graphics.polygon('fill', x1, y1, x2, y2, x3, y3)
            end
        end
    end

    world:add(player, player.x, player.y, player.width, player.height)

    map:addCustomLayer('entities', 6)
    local entityLayer = map.layers['entities']
    entityLayer.sprites = { player }

    function entityLayer:removeEntity(e)
        local t = {}
        for _, o in ipairs(self.sprites) do
            if o ~= e then table.insert(t, o) end
        end
        self.sprites = t
    end

    function entityLayer:draw()
        love.graphics.draw(splatterCanvas)
        
        local sortedEntities = {}
        for i, e in ipairs(self.sprites) do
            sortedEntities[i] = e
        end

        local function sortByY(a, b)
            return a.y < b.y
        end
        table.sort(sortedEntities, sortByY)

        for _, sprite in ipairs(sortedEntities) do
            local x = math.floor(sprite.x)
            local y = math.floor(sprite.y)
            local ox = math.floor(sprite.offsetX or 0)
            local oy = math.floor(sprite.offsetY or 0)

            love.graphics.draw(sprite.image, x + ox, y + oy)

            if sprite.goal then
                love.graphics.line(x + ox + sprite.width / 2, y + oy + sprite.height/2, sprite.goal.x + ox + sprite.width/2, sprite.goal.y + oy + sprite.height/2)
            end

            if sprite.health < sprite.maxHealth then
                love.graphics.setColor(255, 0, 0, 255)
                local x1, y1 = x + ox, y + oy
                local x2, y2 = x1 + sprite.width * (sprite.health/sprite.maxHealth), y1

                love.graphics.line(x1, y1, x2, y2)
                love.graphics.setColor(255, 255, 255, 255)
            end
        end

        ecs:update(0, renderingSystems)
    end

    local AISystem = engine.ecs.processingSystem()
    AISystem.filter = engine.ecs.requireAll('ai_enabled')

    function AISystem:process(e, dt)
        local d = math.sqrt((e.x - player.x)^2 + (e.y - player.y)^2)

        if d < e.viewDistance then
            local function filter(c)
                if c == e then return false end
                if c == player then return false end
                if c.type then
                    if c.type == 'enemy' then return false end
                end
                if c.object then
                    if c.object.type == 'door' then
                        if c.object.properties.open == true then return false end
                    end
                end
                return true
            end

            local x1, y1, x2, y2 = e.x + e.width/2, e.y + e.height/2,
                                   player.x + player.width/2, player. y +player.height/2 
            local _, len = world:querySegment(x1, y1, x2, y2, filter)

            if len == 0 then
                e.path = map:findPath(e, e.x, e.y, player.x, player.y)
            end
        end

        if e.goal then
            e.turnsOnGoal = e.turnsOnGoal or 0
            e.turnsOnGoal = e.turnsOnGoal + 1
            if e.turnsOnGoal > 300 then
                e.turnsOnGoal = 0
                e.goal = nil
                e.path = nil
                return
            end

            local dX, dY = e.goal.x - e.x, e.goal.y - e.y
            local direction = math.atan2(dX, dY)
            local distance = math.sqrt(dX^2 + dY^2)

            local moved = math.min(distance, e.speed * dt)
            dX = moved * math.sin(direction)
            dY = moved * math.cos(direction)


            local function filter(e, other)
                if not other.object then return 'slide' end
                if (other.object.type == 'door') and other.object.properties.open then
                    return false
                end
                return 'slide'
            end

            local actualX, actualY, cols = world:move(e, e.x + dX, e.y + dY, filter)
            e.x, e.y = actualX, actualY

            if (e.x == e.goal.x) and (e.y == e.goal.y) then
                e.goal = nil
                e.turnsOnGoal = 0
            end
        elseif e.path and (#e.path > 0) then
            e.goal = table.remove(e.path, 1)
        end
    end

    local BulletSystem = engine.ecs.processingSystem()
    BulletSystem.filter = engine.ecs.requireAll('bullet')

    function BulletSystem:process(e, dt)
        local x1, y1 = e.x, e.y
        local dS = e.speed * dt
        local x2, y2 = x1 + math.sin(e.direction) * dS, y1 + math.cos(e.direction) * dS

        local function filter(item)
            if item == player then return false end
            if item.object then
                if item.object.type == 'door' then
                    if item.object.properties.open == true then return false end
                end

                if item.object.properties.objectHeight and (item.object.properties.objectHeight < e.height) then
                    return false
                end
            end
            return true
        end

        local colInfo, len = world:querySegmentWithCoords(x1, y1, x2, y2, filter)

        if len > 0 then
            ecs:remove(e)
            local other = colInfo[1].item
            if other.type and (other.type == 'enemy') then
                local ox, oy = colInfo[1].x1, colInfo[1].y1
                local system = love.graphics.newParticleSystem(bloodParticle, 64)
                ecs:addEntity({
                    psystem = system,
                    x = ox,
                    y = oy,
                    duration = 0.5,
                    splatter = true,
                    })
                system:setParticleLifetime(0.3)
                system:setEmissionRate(0)
                system:setSizeVariation(0)
                system:setLinearAcceleration(-400, -400, 400, 400)
                system:emit(64)
            else
                local ox, oy = colInfo[1].x1, colInfo[1].y1
                local system = love.graphics.newParticleSystem(ricochetParticle, 16)
                ecs:addEntity({
                    psystem = system,
                    x = ox,
                    y = oy,
                    duration = 0.5,
                    })
                system:setParticleLifetime(1)
                system:setEmissionRate(0)
                system:setSizeVariation(0)
                system:setLinearAcceleration(-400, -400, 400, 400)
                system:emit(16)
            end

            if other.health then
                other.health = other.health - 2

                if other.health <= 0 then
                    world:remove(other)
                    ecs:remove(other)
                    map.layers['entities']:removeEntity(other)
                end
            end
        else
            e.last_x, e.last_y = e.x, e.y
            e.x, e.y = x2, y2
        end
    end

    local BulletRenderingSystem = engine.ecs.processingSystem()
    BulletRenderingSystem.filter = engine.ecs.requireAll('bullet')
    BulletRenderingSystem.renderer = true

    function BulletRenderingSystem:process(e, dt)
        local x1, y1 = e.last_x, e.last_y
        local x2, y2 = e.x, e.y

        love.graphics.setColor(255, 255, 0, 255)
        love.graphics.line(x1, y1, x2, y2)
        love.graphics.setColor(255, 255, 255, 255)
    end


    local ParticleSystem = engine.ecs.processingSystem()
    ParticleSystem.filter = engine.ecs.requireAll('psystem')

    function ParticleSystem:process(e, dt)
        if e.duration then
            e.duration = e.duration - dt

            if e.duration <= 0 then
                ecs:remove(e)
                return
            end
        end

        e.psystem:update(dt)
    end

    local ParticleRenderingSystem = engine.ecs.processingSystem()
    ParticleRenderingSystem.filter = engine.ecs.requireAll('psystem')
    ParticleRenderingSystem.renderer = true

    function ParticleRenderingSystem:process(e, dt)
        love.graphics.draw(e.psystem, e.x, e.y)

        if e.splatter then
            local oldcanvas = love.graphics.getCanvas()
            love.graphics.push()
            love.graphics.origin()
            love.graphics.setScissor()
            love.graphics.setCanvas(splatterCanvas)
            love.graphics.draw(e.psystem, e.x, e.y)
            love.graphics.setCanvas(oldcanvas)
            love.graphics.pop()
        end
    end

    ecs = engine.ecs.world(
        AISystem,
        BulletSystem,
        BulletRenderingSystem,
        ParticleSystem,
        ParticleRenderingSystem,
        --
        player)

    -- spawn enemies
    local enemySprite = love.graphics.newImage('game/resources/noob.png')

    for _, obj in ipairs(map.layers['objects'].objects) do
        if obj.type == 'enemySpawn' then
            local e = {
                image = enemySprite,
                type = 'enemy',
                x = obj.x,
                y = obj.y,
                width = 14,
                height = 10,
                offsetY = -5,
                ai_enabled = true,
                speed = 48,
                viewDistance = 320,
                name = 'enemy X',
                health = 10,
                maxHealth = 10,
            }
            world:add(e, e.x, e.y, 15, 10)
            table.insert(entityLayer.sprites, e)
            ecs:addEntity(e)
        end
    end

    camera = engine.camera(player.x, player.y)
end

function state:update(dt)
    local goalX, goalY, playerSpeed = player.x, player.y, 64
    if love.keyboard.isDown('w') then
        goalY = player.y - playerSpeed * dt
    elseif love.keyboard.isDown('s') then
        goalY = player.y + playerSpeed * dt
    end
    if love.keyboard.isDown('a') then
        goalX = player.x - playerSpeed * dt
    elseif love.keyboard.isDown('d') then
        goalX = player.x + playerSpeed * dt
    end

    local function filter(e, other)
        if not other.object then return 'slide' end
        if (other.object.type == 'door') and other.object.properties.open then
            return false
        end
        return 'slide'
    end

    local actualX, actualY, cols = world:move(player, goalX, goalY, filter)
    player.x, player.y = actualX, actualY

    -- open the doors we collided with
    for _, col in ipairs(cols) do
        if col.other.object and (col.other.object.type == 'door') then
            col.other.object.properties.open = true
            map:swapTile(col.other.object.tileInstance, map.tiles[col.other.properties.openGID + 1])
        end
    end

    -- shoot here
    if player.gun.cooldown > 0 then
        player.gun.cooldown = player.gun.cooldown - dt
    end
    if player.gun.reloading and (player.gun.reloading > 0) then
        player.gun.reloading = player.gun.reloading - dt

        if player.gun.reloading <= 0 then
            player.gun.reloading = nil
            player.gun.mag = player.gun.magsize
            love.mouse.setCursor(cursorCrosshair)
        end
    end

    if love.mouse.isDown(1) and (player.gun.cooldown <= 0) and (not player.gun.reloading) then
        -- shoot
        local x1, y1 = player.x + player.width/2, player.y + player.height/2
        local x2, y2 = camera:mousePosition()
        local dir = math.atan2(x2 - x1, y2 - y1)
        local bullet = {
            x = x1,
            y = y1,
            direction = dir,
            speed = player.gun.bullet_speed,
            bullet = true,
            height = player.eyeLevel,
        }
        ecs:addEntity(bullet)

        player.gun.cooldown = 1/(player.gun.firerate / 60)

        -- check if we shot the last bullet
        player.gun.mag = player.gun.mag - 1
        if player.gun.mag <= 0 then
            player.gun.reloading = player.gun.reload_time
            love.mouse.setCursor(cursorInvalid)
        end
    end

    player.vision = map:raycastVision(player)

    ecs:update(dt, processingSystems)


    do
        local x1, y1 = player.x, player.y
        local x2, y2 = camera:mousePosition()
        local x3, y3 = (x1+x2)/2, (y1+y2)/2
        camera:lookAt(math.floor(x3), math.floor(y3))

        local mx, my = love.mouse.getPosition()
        local sx, sy = camera:cameraCoords(x1, y1)
        local gw = love.graphics.getWidth()
        local d = math.sqrt((mx - sx)^2 + (my - sy)^2)
        local r = math.max(1 - (math.min(d, gw)/gw), 0)
        local r2 = r + 1

        camera:zoomTo(r2)
    end
end

function state:keypressed(key, code)
    if key == 'c' then
        if player.crouching then
            player.crouching = false
            player.eyeLevel = player.eyeLevelStanding
        else
            player.crouching = true
            player.eyeLevel = player.eyeLevelCrouching
        end
    end
end

function state:draw()
    local gw, gh = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()

    camera:attach()
    love.graphics.setBackgroundColor(24, 24, 24, 255)
    love.graphics.setColor(128, 128, 128, 255)
    map.layers['entities'].visible = false
    map:draw()
    map.layers['entities'].visible = true
    love.graphics.setColor(255, 255, 255, 255)

    love.graphics.stencil(player.drawVision, 'replace', 1)
    love.graphics.setStencilTest('greater', 0)

    map:draw()


    love.graphics.setStencilTest()

    --love.graphics.setColor(255, 0, 255, 64)
    --player.drawVision(0)
    --love.graphics.setColor(255, 255, 255, 255)
    camera:detach()

    do
        local gunstatus = ''
        if player.gun.reloading then
            gunstatus = string.format('reloading %.1fs', player.gun.reloading)
        else
            gunstatus = string.format('%d/%d', player.gun.mag, player.gun.magsize)
        end
        local x, y = mx + 16, my
        love.graphics.print(gunstatus, x, y)
    end

    local fps = love.timer.getFPS()
    love.graphics.print(fps .. ' FPS', 4, 4)
end

return state
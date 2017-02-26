--[[
     DragonBones
--]]

local lovebone = require 'engine.thirdparty.lovebone'
local json = require 'engine.thirdparty.dkjson'

-- for debug
local inspect = require 'engine.thirdparty.inspect'

local skeleton = {
    __file_cache = {},
    __texture_cache = {},
}

local function get_decoded(filename, nocache)
    local jsondata
    if skeleton.__file_cache[filename] and not nocache then
        jsondata = skeleton.__file_cache[filename]
    else
        local filedata, len = love.filesystem.read(filename)
        assert(len, filedata)
        jsondata = assert(json.decode(filedata))
        skeleton.__file_cache[filename] = jsondata
    end

    return jsondata
end

local function get_texture(filename, imagename, nocache)
    local path = filename:match('(.*/)')
    local actual = path .. imagename

    if skeleton.__texture_cache[actual] and not nocache then
        return skeleton.__texture_cache[actual]
    end

    local texture = love.graphics.newImage(actual)
    skeleton.__texture_cache[actual] = texture

    return texture
end

function skeleton.loadTexture(texdata, filename, nocache)

    local texture = get_texture(filename, texdata.imagePath, nocache)
    local sw, sh = texture:getDimensions()
    local quads = {}

    for i, st in ipairs(texdata.SubTexture) do
        local q = love.graphics.newQuad(
            st.x,
            st.y,
            st.width,
            st.height,
            sw, sh)
        quads[st.name] = q
    end

    return {
        texture = texture,
        quads = quads
    }
end

function skeleton.loadSkeleton(skedata)
    local ske = lovebone.newSkeleton()

    assert(not ske.name)
    ske.name = skedata.name
    armature = skedata.armature[1]

    -- load bones
    for i, b in ipairs(armature.bone) do
        local t = b.transform or {}
        local bone = lovebone.newBone(
            b.parent,
            i,
            {b.length or 0, 0},
            math.rad((t.skX or 0)),
            {t.x or 0, t.y or 0},
            {1, 1})
        ske:SetBone(b.name, bone)
    end

    ske:Validate()
    assert(ske:IsValid())
    return ske
end

function skeleton.newActor(skefile, texfile, nocache)
    local skedata = get_decoded(skefile, nocache)
    local texdata = get_decoded(texfile, nocache)

    local ske = skeleton.loadSkeleton(skedata)
    local tex = skeleton.loadTexture(texdata, texfile, nocache)
    local actor = lovebone.newActor(ske)

    -- load animations
    local armature = skedata.armature[1]
    for i, a in ipairs(armature.animation) do
        local animation = lovebone.newAnimation(ske)
        for bi, b in ipairs(a.bone) do
            local keyTime = 0

            for fi, frame in ipairs(b.frame) do
                local t = frame.transform or {}
                animation:AddKeyFrame(
                    b.name,
                    keyTime,
                    math.rad((t.skX or 0)),
                    {t.x or 0, t.y or 0},
                    nil)
                keyTime = keyTime + frame.duration / armature.frameRate
            end
        end
        actor:GetTransformer():SetTransform(a.name, animation)
    end

    -- load slots
    local slots = {}
    for i, slot in ipairs(armature.slot) do
        slots[slot.name] = {
            z = slot.z,
            name = slot.name,
            parent = slot.parent,
            color = slot.color or {255, 255, 255}
        }
    end
    actor.slots = slots

    -- load skin
    for i, ss in ipairs(armature.skin[1].slot) do
        local dis = ss.display[1]
        local t = dis.transform or {}
        local q = assert(tex.quads[dis.name], 'no quad ' .. dis.name)
        local vis = lovebone.newVisual(
            tex.texture,
            q)
        local vw, vh = vis:GetDimensions()
        vis:SetOrigin(vw/2, vh/2)

        local attachment = lovebone.newAttachment(vis)
        attachment:SetRotation(math.rad((t.skX or 0)))
        attachment:SetTranslation(t.x or 0, t.y or 0)

        local slot = actor.slots[ss.name]
        actor:SetAttachment(slot.parent, ss.name, attachment)
    end

    -- rotate it?
    actor:GetTransformer():GetRoot().rotation = math.rad(90)

    local list_of_bones = {}
    for i, b in ipairs(armature.bone) do
        list_of_bones[i] = b.name
    end

    actor:SetDebug(list_of_bones, true, {
        boneLineColor = {255, 255, 255, 255},
        boneTextColor = {255, 255, 255, 255},
        --attachmentLineColor = {255, 000, 255, 255},
        --AttachmentTextColor = {255, 000, 255, 255},
        })

    return actor
end

return skeleton
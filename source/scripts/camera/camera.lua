local gfx <const> = playdate.graphics
local ldtk <const> = LDtk

local SCREEN_WIDTH <const> = 400
local SCREEN_HEIGHT <const> = 240

local GRAVITY <const> = 0.8
local TRANSITION_FRAMES <const> = 24
local COMMIT_DEPTH <const> = 29   -- how far past the edge the apex must reach
local CAMERA_Y_OFFSET <const> = 16   -- lowers the view by one tile to show the top of the room below

local function smoothstep(t)
    return t * t * (3 - 2 * t)
end
local PEEK <const> = 16


local FADE_FRAMES <const> = 8   -- frames to fade out (and again to fade in)
local FADE_HOLD <const> = 3     -- frames held fully black

-- Shift the view toward a vertical neighbour: down if there is a room below,
-- otherwise up if there is a room above. Rooms with both prefer the one below.
local PEEK <const> = 16

local function verticalOffset(levelName)
    local peek = ldtk.get_custom_data(levelName, "cameraPeek")
    if peek == "Down" then return PEEK end
    if peek == "Up" then return -PEEK end
    return 0
end

-- camera position that follows (px, py) in world coordinates: scrolls across horizontal
-- neighbours, but stays clamped vertically to the room
local function followTarget(levelName, rect, px, py)
    local camMinX = rect.x
    local camMaxX = math.max(rect.x, rect.x + rect.width - SCREEN_WIDTH)
    local maxY = math.max(0, rect.height - SCREEN_HEIGHT)

    local rpx = math.floor(px + 0.5)
    local rpy = math.floor(py + 0.5)

    local x = math.max(camMinX, math.min(rpx - SCREEN_WIDTH / 2, camMaxX))
    local y = math.max(0, math.min(rpy - rect.y - SCREEN_HEIGHT / 2, maxY))
    return x, rect.y + y + verticalOffset(levelName)
end

local function willLeaveNorth(y, vy)
    local apex = y - (vy * vy) / (2 * GRAVITY)
    return apex < -COMMIT_DEPTH
end

---@class Camera
---@field x number
---@field y number
local Camera = {}
Camera.__index = Camera

-- scene must expose: player, levelRect, level_name, loadLevel(), setActiveLevel()
-- player and camera positions are in world coordinates
function Camera.new(scene)
    local self = setmetatable({
        scene = scene,
        x = 0,
        y = 0,
        fade = 0,   -- 0 = clear, 1 = fully black
    }, Camera)

    local overlay = gfx.sprite.new()
    overlay:setSize(SCREEN_WIDTH, SCREEN_HEIGHT)
    overlay:setCenter(0, 0)
    overlay:moveTo(0, 0)
    overlay:setZIndex(32767)
    overlay:setIgnoresDrawOffset(true)
    overlay:setVisible(false)
    function overlay.draw()
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(self.fade, gfx.image.kDitherTypeBayer8x8)
        gfx.fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    end
    overlay:add()
    self.overlay = overlay

    return self
end

function Camera:setFade(f)
    if f == self.fade then return end
    self.fade = f
    self.overlay:setVisible(f > 0)
    self.overlay:markDirty()
end

function Camera:shake(magnitude, frames)
    self.shakeMagnitude = magnitude
    self.shakeFrames = frames
    self.shakeTotalFrames = frames
end

function Camera:update()
    local scene = self.scene
    local t = self.transition
    if t then
        t.frame += 1
        if t.mode == "fade" then
            local f = t.frame
            local fade
            if f <= FADE_FRAMES then
                fade = f / FADE_FRAMES
            elseif f <= FADE_FRAMES + FADE_HOLD then
                fade = 1
            else
                fade = 1 - (f - FADE_FRAMES - FADE_HOLD) / FADE_FRAMES
            end
            if f >= FADE_FRAMES then          -- screen is black: jump to the new room
                self.x, self.y = t.toX, t.toY
            end
            self:setFade(math.max(fade, 0))
        else
            local k = smoothstep(math.min(t.frame / t.frames, 1))
            self.x = t.fromX + (t.toX - t.fromX) * k
            self.y = t.fromY + (t.toY - t.fromY) * k
        end
        if t.frame >= t.frames then
            self:finishTransition()
        end
    else
        self.x, self.y = followTarget(scene.level_name, scene.levelRect, scene.player.x, scene.player.y)
    end

    local shakeX, shakeY = 0, 0
    if self.shakeFrames and self.shakeFrames > 0 then
        local strength = math.floor(self.shakeMagnitude * (self.shakeFrames / self.shakeTotalFrames))
        shakeX = math.random(-strength, strength)
        shakeY = math.random(-strength, strength)
        self.shakeFrames -= 1
    end

    gfx.setDrawOffset(-self.x + shakeX, -self.y + shakeY)
end

function Camera:checkLevelExit(p)
    local scene = self.scene
    if self.transition then
        self.lastPlayerY = nil
        return
    end

    -- per-frame vertical velocity measured from actual movement (negative = up)
    local vy = 0
    if self.lastPlayerY then
        vy = p.y - self.lastPlayerY
    end
    self.lastPlayerY = p.y

    local r = scene.levelRect
    local localX, localY = p.x - r.x, p.y - r.y
    local dir
    if localY > r.height then
        dir = "south"
    elseif localY < 0 and vy < 0 and willLeaveNorth(localY, vy) then
        dir = "north"
    elseif localX < 0 then
        dir = "west"
    elseif localX > r.width then
        dir = "east"
    else
        return
    end

    local vertical = dir == "north" or dir == "south"
    for _, name in ipairs(ldtk.get_neighbours(scene.level_name, dir) or {}) do
        local nr = ldtk.get_rect(name)
        local inside
        if vertical then
            inside = p.x >= nr.x and p.x < nr.x + nr.width
        else
            inside = p.y >= nr.y and p.y < nr.y + nr.height
        end
        if inside then
            self:startTransition(name, nr, vertical and "slide" or "fade")
            return
        end
    end
end

function Camera:startTransition(name, nr, mode)
    local scene = self.scene
    scene:loadLevel(name)

    for _, s in ipairs(gfx.sprite.getAllSprites()) do
        s:setUpdatesEnabled(false)
    end

    local tx, ty = followTarget(name, nr, scene.player.x, scene.player.y)

    self.transition = {
        name = name, frame = 0, mode = mode,
        frames = mode == "fade" and (FADE_FRAMES * 2 + FADE_HOLD) or TRANSITION_FRAMES,
        fromX = self.x, fromY = self.y,
        toX = tx, toY = ty,
    }
end

function Camera:finishTransition()
    local scene = self.scene
    local t = self.transition
    self.transition = nil

    scene:setActiveLevel(t.name)    -- unfreezes the new room, loads/unloads its neighbours
    scene.player:setUpdatesEnabled(true)

    self.x, self.y = t.toX, t.toY
end

return Camera

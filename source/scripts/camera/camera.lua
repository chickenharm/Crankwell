local gfx <const> = playdate.graphics
local ldtk <const> = LDtk

local SCREEN_WIDTH <const> = 400
local SCREEN_HEIGHT <const> = 240

local GRAVITY <const> = 0.8
local TRANSITION_FRAMES <const> = 24
local COMMIT_DEPTH <const> = 29   -- how far past the edge the apex must reach

local function smoothstep(t)
    return t * t * (3 - 2 * t)
end

-- camera position that follows (px, py) inside a room, clamped to that room
local function followTarget(rect, px, py)
    local maxX = math.max(0, rect.width - SCREEN_WIDTH)
    local maxY = math.max(0, rect.height - SCREEN_HEIGHT)
    local x = math.max(0, math.min(px - SCREEN_WIDTH / 2, maxX))
    local y = math.max(0, math.min(py - SCREEN_HEIGHT / 2, maxY))
    return x, y
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

-- scene must expose: player, levelRect, level_name, goToLevel(), addTileLayers()
function Camera.new(scene)
    return setmetatable({
        scene = scene,
        x = 0,
        y = 0,
    }, Camera)
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
        local k = smoothstep(math.min(t.frame / TRANSITION_FRAMES, 1))
        self.x = t.fromX + (t.toX - t.fromX) * k
        self.y = t.fromY + (t.toY - t.fromY) * k
        if t.frame >= TRANSITION_FRAMES then
            self:finishTransition()
        end
    else
        self.x, self.y = followTarget(scene.levelRect, scene.player.x, scene.player.y)
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
    local dir
    if p.y > r.height then
        dir = "south"
    elseif p.y < 0 and vy < 0 and willLeaveNorth(p.y, vy) then
        dir = "north"
    else
        return
    end

    -- several rooms can touch this edge (varying widths), so pick the one under the player
    local worldX = r.x + scene.player.x
    for _, name in ipairs(ldtk.get_neighbours(scene.level_name, dir) or {}) do
        local nr = ldtk.get_rect(name)
        if worldX >= nr.x and worldX < nr.x + nr.width then
            self:startTransition(name, nr)
            return
        end
    end
end

function Camera:startTransition(name, nr)
    local scene = self.scene
    local r = scene.levelRect
    -- where the new room's origin sits in the current room's coordinates
    local dx, dy = nr.x - r.x, nr.y - r.y

    -- draw the neighbour next to the current room (visual only)
    scene:addTileLayers(name, dx, dy, false)

    -- freeze everything while sliding
    for _, s in ipairs(gfx.sprite.getAllSprites()) do
        s:setUpdatesEnabled(false)
    end

    -- player position and camera target in the new room's local coordinates
    local px, py = scene.player.x - dx, scene.player.y - dy
    local tx, ty = followTarget(nr, px, py)

    self.transition = {
        name = name, rect = nr, frame = 0,
        fromX = self.x, fromY = self.y,
        toX = tx + dx, toY = ty + dy,   -- target expressed in current coordinates
        px = px, py = py, camX = tx, camY = ty,
    }
end

function Camera:finishTransition()
    local scene = self.scene
    local t = self.transition
    self.transition = nil

    scene:goToLevel(t.name)         -- removeAll() also removes the player...
    scene.player:add()              -- ...so put it back
    scene.player:moveTo(t.px, t.py)
    scene.player:setUpdatesEnabled(true)

    self.x, self.y = t.camX, t.camY
end

return Camera

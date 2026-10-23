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


-- Shift the view toward a vertical neighbour: down if there is a room below,
-- otherwise up if there is a room above. Rooms with both prefer the one below.
local PEEK <const> = 16

local function verticalOffset(levelName)
    local peek = ldtk.get_custom_data(levelName, "cameraPeek")
    if peek == "Down" then return PEEK end
    if peek == "Up" then return -PEEK end
    if peek == "None" then return 0 end

    local south = ldtk.get_neighbours(levelName, "south")
    if south and #south > 0 then return PEEK end
    local north = ldtk.get_neighbours(levelName, "north")
    if north and #north > 0 then return -PEEK end
    return 0
end
-- horizontal extent the camera may scroll across: the room plus its east/west neighbours
local function horizontalBounds(levelName, rect)
    local minX, maxX = rect.x, rect.x + rect.width
    for _, n in ipairs(ldtk.get_neighbours(levelName, "west") or {}) do
        minX = math.min(minX, ldtk.get_rect(n).x)
    end
    for _, n in ipairs(ldtk.get_neighbours(levelName, "east") or {}) do
        local nr = ldtk.get_rect(n)
        maxX = math.max(maxX, nr.x + nr.width)
    end
    return minX, maxX
end

-- camera position that follows (px, py) in world coordinates: scrolls across horizontal
-- neighbours, but stays clamped vertically to the room
local function followTarget(levelName, rect, px, py)
    local minX, maxX = horizontalBounds(levelName, rect)
    local camMaxX = math.max(minX, maxX - SCREEN_WIDTH)
    local maxY = math.max(0, rect.height - SCREEN_HEIGHT)
    local x = math.max(minX, math.min(px - SCREEN_WIDTH / 2, camMaxX))
    local y = math.max(0, math.min(py - rect.y - SCREEN_HEIGHT / 2, maxY))
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
            if vertical then
                self:startTransition(name, nr)
            else
                -- the camera already scrolls across, so just hand over the active room
                scene:setActiveLevel(name)
            end
            return
        end
    end
end

function Camera:startTransition(name, nr)
    local scene = self.scene

    -- normally already preloaded; this covers a still-queued neighbour
    scene:loadLevel(name)

    -- freeze everything while sliding
    for _, s in ipairs(gfx.sprite.getAllSprites()) do
        s:setUpdatesEnabled(false)
    end

    local tx, ty = followTarget(name, nr, scene.player.x, scene.player.y)

    self.transition = {
        name = name, frame = 0,
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

import "CoreLibs/sprites"

local gfx <const> = playdate.graphics
local ldtk <const> = LDtk

local TILE_SIZE = 16

local TRANSITION_FRAMES <const> = 24

TAGS = {
    Player = 1,
    Hazzard = 2,
    Pickup = 3,
    Enemy = 4,
    Breakable = 5
}

Z_INDEXES = {
    Player = 100,
    Pickup = 50,
    Enemy = 40,
    Hazzard = 20
}

local usePrecomputedLevels = not playdate.isSimulator

ldtk.load("levels/world.ldtk", usePrecomputedLevels)

if playdate.isSimulator then
    ldtk.export_to_lua_files()
end


local SCREEN_WIDTH = 400
local SCREEN_HEIGHT = 240

local GRAVITY = 0.8

ldtk.load("Levels/World.ldtk", false)

-- Wrappers look up the class globals at call time, so load order doesn't matter
local entitySpawners <const> = {
    Spike = function(x, y) Spike(x, y) end,
    Spikeball = function(x, y, e) Spikeball(x, y, e) end,
    SpikeBall_FixedDistance = function(x, y, e) SpikeBall_FixedDistance(x, y, e) end,
    PatrolEnemy = function(x, y, e) PatrolEnemy(x, y, e) end,
    ArmoredEnemy = function(x, y, e) ArmoredEnemy(x, y, e) end,
    Ability = function(x, y, e) Ability(x, y, e) end,
    Key = function(x, y, e) Key(x, y, e) end,
    KeyDoor = function(x, y, e) KeyDoor(x, y, e) end,
    SwitchDoor = function(x, y, e) SwitchDoor(x, y, e) end,
    Switch = function(x, y, e) Switch(x, y, e) end,
    Breakable = function(x, y, e)
        BreakableBlock(x, y, ldtk.generate_image_from_entity(e))
    end,
}

---@class GameScene
---@field init fun(self: GameScene)
local GameScene = {}

function GameScene:init()
    self:goToLevel("Level_1")

    self.levelRect = ldtk.get_rect("Level_1")
    self.cameraX = 0
    self.cameraY = 0

    self.spawnX = 3 * TILE_SIZE
    self.spawnY = 11 * TILE_SIZE
    self.player = Player(self.spawnX, self.spawnY, self)
end

local function smoothstep(t)
    return t * t * (3 - 2 * t)
end

local COMMIT_DEPTH <const> = 29   -- how far past the edge the apex must reach

function GameScene:resetPlayer()
    self.player:moveTo(self.spawnX, self.spawnY)
end

function GameScene:shakeCamera(magnitude, frames)
    self.shakeMagnitude = magnitude
    self.shakeFrames = frames
    self.shakeTotalFrames = frames
end

-- camera position that follows (px, py) inside a room, clamped to that room
local function followTarget(rect, px, py)
    local maxX = math.max(0, rect.width - SCREEN_WIDTH)
    local maxY = math.max(0, rect.height - SCREEN_HEIGHT)
    local x = math.max(0, math.min(px - SCREEN_WIDTH / 2, maxX))
    local y = math.max(0, math.min(py - SCREEN_HEIGHT / 2, maxY))
    return x, y
end

function GameScene:updateCamera()
    local t = self.transition
    if t then
        t.frame += 1
        local k = smoothstep(math.min(t.frame / TRANSITION_FRAMES, 1))
        self.cameraX = t.fromX + (t.toX - t.fromX) * k
        self.cameraY = t.fromY + (t.toY - t.fromY) * k
        if t.frame >= TRANSITION_FRAMES then
            self:finishTransition()
        end
    else
        self.cameraX, self.cameraY = followTarget(self.levelRect, self.player.x, self.player.y)
    end

    local shakeX, shakeY = 0, 0
    if self.shakeFrames and self.shakeFrames > 0 then
        local strength = math.floor(self.shakeMagnitude * (self.shakeFrames / self.shakeTotalFrames))
        shakeX = math.random(-strength, strength)
        shakeY = math.random(-strength, strength)
        self.shakeFrames -= 1
    end

    gfx.setDrawOffset(-self.cameraX + shakeX, -self.cameraY + shakeY)
end

local function willLeaveNorth(y, vy)
    local apex = y - (vy * vy) / (2 * GRAVITY)
    return apex < -COMMIT_DEPTH
end

function GameScene:checkLevelExit(p)
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

    local r = self.levelRect
    local dir
    if p.y > r.height then
        dir = "south"
    elseif p.y < 0 and vy < 0 and willLeaveNorth(p.y, vy) then
        dir = "north"
    else
        return
    end

    -- several rooms can touch this edge (varying widths), so pick the one under the player
    local worldX = r.x + self.player.x
    for _, name in ipairs(ldtk.get_neighbours(self.level_name, dir) or {}) do
        local nr = ldtk.get_rect(name)
        if worldX >= nr.x and worldX < nr.x + nr.width then
            self:startTransition(name, nr)
            return
        end
    end
end

function GameScene:startTransition(name, nr)
    local r = self.levelRect
    -- where the new room's origin sits in the current room's coordinates
    local dx, dy = nr.x - r.x, nr.y - r.y

    -- draw the neighbour next to the current room (visual only)
    self:addTileLayers(name, dx, dy, false)

    -- freeze everything while sliding
    for _, s in ipairs(gfx.sprite.getAllSprites()) do
        s:setUpdatesEnabled(false)
    end

    -- player position and camera target in the new room's local coordinates
    local px, py = self.player.x - dx, self.player.y - dy
    local tx, ty = followTarget(nr, px, py)

    self.transition = {
        name = name, rect = nr, frame = 0,
        fromX = self.cameraX, fromY = self.cameraY,
        toX = tx + dx, toY = ty + dy,   -- target expressed in current coordinates
        px = px, py = py, camX = tx, camY = ty,
    }
end

function GameScene:finishTransition()
    local t = self.transition
    self.transition = nil

    self:goToLevel(t.name)          -- removeAll() also removes the player...
    self.player:add()               -- ...so put it back
    self.player:moveTo(t.px, t.py)
    self.player:setUpdatesEnabled(true)

    self.cameraX, self.cameraY = t.camX, t.camY
end

function GameScene:addTileLayers(level_name, offsetX, offsetY, withWalls)
    for layer_name, layer in pairs(ldtk.get_layers(level_name) or {}) do
        if layer.tiles then
            local tilemap = ldtk.create_tilemap(level_name, layer_name)
            if tilemap then
                local layerSprite = gfx.sprite.new()
                layerSprite:setTilemap(tilemap)
                layerSprite:setCenter(0, 0)
                layerSprite:moveTo(offsetX, offsetY)
                layerSprite:setZIndex(layer.zIndex)
                layerSprite:add()

                if withWalls then
                    local emptyTiles = ldtk.get_empty_tileIDs(level_name, "Solid", layer_name)
                    if emptyTiles then
                        gfx.sprite.addWallSprites(tilemap, emptyTiles)
                    end
                end
            end
        end
    end
end

function GameScene:goToLevel(level_name)
    if not level_name then return end
    self.level_name = level_name
    self.levelRect = ldtk.get_rect(level_name)
    gfx.sprite.removeAll()

    self:addTileLayers(level_name, 0, 0, true)

    for _, entity in ipairs(ldtk.get_entities(level_name) or {}) do
        local spawn = entitySpawners[entity.name]
        if spawn then
            spawn(entity.position.x, entity.position.y, entity)
        end
    end
end

return GameScene
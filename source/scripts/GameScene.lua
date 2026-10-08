import "CoreLibs/sprites"

local gfx <const> = playdate.graphics
local ldtk <const> = LDtk

local TILE_SIZE = 16

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

GROUPS = {
    Wall = 1
}

local usePrecomputedLevels = not playdate.isSimulator

ldtk.load("levels/world.ldtk", usePrecomputedLevels)

if playdate.isSimulator then
    ldtk.export_to_lua_files()
end


local SCREEN_WIDTH = 400
local SCREEN_HEIGHT = 240

ldtk.load("Levels/World.ldtk", false)

---@class GameScene
---@field init fun(self: GameScene)
local GameScene = {}

function GameScene:init()
    self:goToLevel("Level_1")

    self.levelRect = ldtk.get_rect("Level_1")
    self.cameraX = 0
    self.cameraY = 0

    self.spawnX = 3 * TILE_SIZE
    self.spawnY = 5 * TILE_SIZE
    self.player = Player(self.spawnX, self.spawnY, self)
end


function GameScene:resetPlayer()
    self.player:moveTo(self.spawnX, self.spawnY)
end

function GameScene:shakeCamera(magnitude, frames)
    self.shakeMagnitude = magnitude
    self.shakeFrames = frames
    self.shakeTotalFrames = frames
end

function GameScene:updateCamera()
    local targetX = self.player.x - SCREEN_WIDTH / 2
    local targetY = self.player.y - SCREEN_HEIGHT / 2

    local maxCameraX = math.max(0, self.levelRect.width - SCREEN_WIDTH)
    local maxCameraY = math.max(0, self.levelRect.height - SCREEN_HEIGHT)

    self.cameraX = math.max(0, math.min(targetX, maxCameraX))
    self.cameraY = math.max(0, math.min(targetY, maxCameraY))

    local shakeX, shakeY = 0, 0
    if self.shakeFrames and self.shakeFrames > 0 then
        -- magnitude decays linearly to zero over the shake duration
        local strength = math.floor(self.shakeMagnitude * (self.shakeFrames / self.shakeTotalFrames))
        shakeX = math.random(-strength, strength)
        shakeY = math.random(-strength, strength)
        self.shakeFrames -= 1
    end

    gfx.setDrawOffset(-self.cameraX + shakeX, -self.cameraY + shakeY)
end

function GameScene:goToLevel(level_name)
    if not level_name then return end
    self.level_name = level_name
    gfx.sprite.removeAll()

    for layer_name, layer in pairs(ldtk.get_layers(level_name) or {}) do
        if layer.tiles then
            local tilemap = ldtk.create_tilemap(level_name, layer_name)

            if tilemap then

                local layerSprite = gfx.sprite.new()
                layerSprite:setTilemap(tilemap)
                layerSprite:setCenter(0, 0)
                layerSprite:moveTo(0, 0)
                layerSprite:setZIndex(layer.zIndex)
                layerSprite:add()

                local emptyTiles = ldtk.get_empty_tileIDs(level_name, "Solid", layer_name)
                if emptyTiles then
                    gfx.sprite.addWallSprites(tilemap, emptyTiles)
                end
            end
        end
    end

    for _, entity in ipairs(ldtk.get_entities(level_name) or {}) do
        local entityX, entityY = entity.position.x, entity.position.y
        local entityName = entity.name
        if entityName == "Spike" then
            Spike(entityX, entityY)
        elseif entityName == "Spikeball" then
            Spikeball(entityX, entityY, entity)
        elseif entityName == "SpikeBall_FixedDistance" then
            SpikeBall_FixedDistance(entityX, entityY, entity)
        elseif entityName == "PatrolEnemy" then
            Enemy(entityX, entityY, entity)
        elseif entityName == "Ability" then
            Ability(entityX, entityY, entity)
        elseif entityName == "Breakable" then
            BreakableBlock(entityX, entityY, ldtk.generate_image_from_entity(entity))
        end
    end
end

return GameScene
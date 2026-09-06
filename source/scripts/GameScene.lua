import "CoreLibs/sprites"

local gfx <const> = playdate.graphics
local ldtk <const> = LDtk

local TILE_SIZE = 16

TAGS = {
    Pickup = 1,
    Player = 2,
    Hazzard = 3
}

Z_INDEXES = {
    Player = 100,
    Hazzard = 20
}


local SCREEN_WIDTH = 400
local SCREEN_HEIGHT = 240

ldtk.load("Levels/World.ldtk", false)

---@class GameScene
---@field init fun(self: GameScene)
local GameScene = {}

function GameScene:init()
    self:goToLevel("Level_0")

    self.levelRect = ldtk.get_rect("Level_0")
    self.cameraX = 0
    self.cameraY = 0

    self.spawnX = 3 * TILE_SIZE
    self.spawnY = 5 * TILE_SIZE
    self.player = Player(self.spawnX, self.spawnY)
end


function GameScene:resetPlayer()
    self.player:moveTo(self.spawnX, self.spawnY)
end

function GameScene:updateCamera()
    local targetX = self.player.x - SCREEN_WIDTH / 2
    local targetY = self.player.y - SCREEN_HEIGHT / 2

    local maxCameraX = math.max(0, self.levelRect.width - SCREEN_WIDTH)
    local maxCameraY = math.max(0, self.levelRect.height - SCREEN_HEIGHT)

    self.cameraX = math.max(0, math.min(targetX, maxCameraX))
    self.cameraY = math.max(0, math.min(targetY, maxCameraY))

    gfx.setDrawOffset(-self.cameraX, -self.cameraY)
end

function GameScene:goToLevel(level_name)
    gfx.sprite.removeAll()

local layers = ldtk.get_layers(level_name) or {}
    for layer_name, layer in pairs(layers) do
        if layer and layer.tiles then
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

        for _, entity in ipairs(ldtk.get_entities(level_name)) do
            local entityX, entityY = entity.position.x, entity.position.y
            local entityName = entity.name
            if entityName == "Spike" then
                Spike(entityX, entityY)
            elseif entityName == "Spikeball" then
                Spikeball(entityX, entityY, entity)
            end
        end

    end
end

return GameScene
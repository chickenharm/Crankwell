import "CoreLibs/sprites"

local gfx <const> = playdate.graphics
local ldtk <const> = LDtk

local TILE_SIZE = 16


ldtk.load("Levels/World.ldtk", false)

---@class GameScene
---@field init fun(self: GameScene)
local GameScene = {}

function GameScene:init()
    self:goToLevel("Level_0")
    self.spawnX = 12 * TILE_SIZE
    self.spawnY = 5 * TILE_SIZE
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
    end
end

return GameScene
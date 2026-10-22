import "CoreLibs/sprites"
local Camera = import "scripts/camera/camera"

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

local usePrecomputedLevels = not playdate.isSimulator

ldtk.load("levels/world.ldtk", usePrecomputedLevels)

if playdate.isSimulator then
    ldtk.export_to_lua_files()
end


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
    BigHelmet = function(x, y, e) BigHelmet(x, y, e) end,
    Breakable = function(x, y, e)
        BreakableBlock(x, y, ldtk.generate_image_from_entity(e))
    end,
}

---@class GameScene
---@field init fun(self: GameScene)
local GameScene = {}

function GameScene:init()
    self:goToLevel("Level_0")

    self.levelRect = ldtk.get_rect("Level_0")
    self.camera = Camera.new(self)

    self.spawnX = 3 * TILE_SIZE
    self.spawnY = 10 * TILE_SIZE
    self.player = Player(self.spawnX, self.spawnY, self)
end

function GameScene:resetPlayer()
    self.player:moveTo(self.spawnX, self.spawnY)
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
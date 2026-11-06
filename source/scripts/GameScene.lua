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
    Breakable = 5,
    Checkpoint = 6

}

Z_INDEXES = {
    Player = 100,
    Pickup = 50,
    Enemy = 40,
    Hazzard = 20
}

local ENEMY_ENTITIES <const> = {
    PatrolEnemy = true,
    ArmoredEnemy = true,
    Spikeball = true,
    SpikeBall_FixedDistance = true,
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
    FlyingEnemy = function(x, y, e) FlyingEnemy(x, y, e) end,
    Ability = function(x, y, e) Ability(x, y, e) end,
    Key = function(x, y, e) Key(x, y, e) end,
    KeyDoor = function(x, y, e) KeyDoor(x, y, e) end,
    SwitchDoor = function(x, y, e) SwitchDoor(x, y, e) end,
    Switch = function(x, y, e) Switch(x, y, e) end,
    BigHelmet = function(x, y, e) BigHelmet(x, y, e) end,
    Checkpoint = function(x, y, e) Checkpoint(x, y, e) end,
    Breakable = function(x, y, e)
        BreakableBlock(x, y, ldtk.generate_image_from_entity(e))
    end,
}

---@class GameScene
---@field init fun(self: GameScene)
local GameScene = {}

local NEIGHBOUR_DIRECTIONS <const> = { "north", "south", "east", "west" }

-- Everything lives in world coordinates: a level's content is offset by its LDtk world rect.
function GameScene:init()
    self.loadedLevels = {}   -- level name -> sprites created for that level
    -- in init, next to loadedLevels:
    self.enemySprites = {}   -- level name -> enemy sprites only

    self.wantedLevels = {}   -- active level + its neighbours
    self.pendingLoads = {}
    self.levelStarts = {}     -- level name -> {x, y} from PlayerStart entities
    self.checkpoint = nil     -- { level = "Level_2", x = ..., y = ..., sprite = cp }

    Checkpoint.onActivated = function(cp) self:setCheckpoint(cp) end

    self.spawnLevel = "Level_1"
    gfx.setBackgroundColor(gfx.kColorBlack)
    gfx.clear()
    local spawnRect = ldtk.get_rect(self.spawnLevel)

    self:setActiveLevel(self.spawnLevel, true)
    self.camera = Camera.new(self)

    self.spawnX = spawnRect.x + 2 * TILE_SIZE
    self.spawnY = spawnRect.y + 10 * TILE_SIZE
    self.player = Player(self.spawnX, self.spawnY, self)
end

-- Streams in at most one pending level per frame to avoid a hitch.
function GameScene:update()
    local name = table.remove(self.pendingLoads, 1)
    if name and self.wantedLevels[name] then
        self:loadLevel(name)
    end
end

function GameScene:addTileLayers(level_name, offsetX, offsetY)
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

                local emptyTiles = ldtk.get_empty_tileIDs(level_name, "Solid", layer_name)
                if emptyTiles then
                    gfx.sprite.addWallSprites(tilemap, emptyTiles, offsetX, offsetY)
                end
            end
        end
    end
end

local function snapshotSprites()
    local set = {}
    for _, s in ipairs(gfx.sprite.getAllSprites()) do set[s] = true end
    return set
end

local function spritesCreatedSince(before)
    local list = {}
    for _, s in ipairs(gfx.sprite.getAllSprites()) do
        if not before[s] then list[#list + 1] = s end
    end
    return list
end

-- Spawns a level's tiles, walls and entities, remembering every sprite it created.
function GameScene:loadLevel(level_name)
    if self.loadedLevels[level_name] then return end
    local rect = ldtk.get_rect(level_name)
    if not rect then return end

    local before = {}
    for _, s in ipairs(gfx.sprite.getAllSprites()) do
        before[s] = true
    end

    self:addTileLayers(level_name, rect.x, rect.y)

    self:addTileLayers(level_name, rect.x, rect.y)
    self:spawnEntities(level_name, rect, false)   -- non-enemies

    local sprites = {}
    local isRunning = self.runningLevels[level_name]
    for _, s in ipairs(gfx.sprite.getAllSprites()) do
        if not before[s] then
            sprites[#sprites + 1] = s
            s:setUpdatesEnabled(isRunning)
        end
    end
    self.loadedLevels[level_name] = sprites
    self:spawnEnemies(level_name)

end

function GameScene:unloadLevel(level_name)
    local sprites = self.loadedLevels[level_name]
    if not sprites then return end
    for _, s in ipairs(sprites) do
        s:remove()
    end
    self.loadedLevels[level_name] = nil
    self:removeEnemies(level_name)
end

-- Makes level_name current, keeps it and its neighbours loaded and unloads the rest.
-- The current level and its east/west neighbours (visible while the camera scrolls) run
-- their update(); north/south neighbours stay frozen until the player transitions into them.
function GameScene:setActiveLevel(level_name, loadNow)
      local previous = self.level_name
    if previous and previous ~= level_name then
        self:removeEnemies(previous)
    end
    self.level_name = level_name
    self.levelRect = ldtk.get_rect(level_name)

    local wanted = { [level_name] = true }
    for _, dir in ipairs(NEIGHBOUR_DIRECTIONS) do
        for _, name in ipairs(ldtk.get_neighbours(level_name, dir) or {}) do
            wanted[name] = true
        end
    end
    self.wantedLevels = wanted

    local running = { [level_name] = true }
    for _, dir in ipairs({ "east", "west" }) do
        for _, name in ipairs(ldtk.get_neighbours(level_name, dir) or {}) do
            running[name] = true
        end
    end
    self.runningLevels = running

    for name in pairs(self.loadedLevels) do
        if not wanted[name] then
            self:unloadLevel(name)
        end
    end

    self:loadLevel(level_name)
    self.pendingLoads = {}
    for name in pairs(wanted) do
        if not self.loadedLevels[name] then
            if loadNow then
                self:loadLevel(name)
            else
                self.pendingLoads[#self.pendingLoads + 1] = name
            end
        end
    end

     for name, sprites in pairs(self.loadedLevels) do
        local isRunning = running[name] == true
        for _, s in ipairs(sprites) do s:setUpdatesEnabled(isRunning) end
        for _, s in ipairs(self.enemySprites[name] or {}) do
            s:setUpdatesEnabled(isRunning)
        end
    end
end

function GameScene:setCheckpoint(cp)
    if self.checkpoint and self.checkpoint.sprite == cp then return end
    if self.checkpoint and self.checkpoint.sprite then
        -- optional: deactivate the old one visually, if it's still loaded
    end
    cp:activate()
    self.checkpoint = {
        level = self.level_name,
        x = cp.levelRespawnX,
        y = cp.levelRespawnY,
        sprite = cp,
    }
end

function GameScene:getRespawnPoint()
    -- Checkpoint only counts if it's in the level the player is currently in
    local cp = self.checkpoint
    if cp and cp.level == self.level_name then
        return cp.x, cp.y
    end

    -- Fallback: start of the current level
    local start = self.levelStarts[self.level_name]
    if start then
        return start.x, start.y
    end
    local rect = self.levelRect
    return rect.x + 2 * TILE_SIZE, rect.y + 10 * TILE_SIZE
end

function GameScene:resetPlayer()
    local x, y = self:getRespawnPoint()
    self:setActiveLevel(self.level_name, true)  -- make sure neighbours are loaded
    self.player:moveTo(x, y)
end


-- enemies == true spawns only enemy entities, false spawns everything else
function GameScene:spawnEntities(level_name, rect, enemies)
    for _, entity in ipairs(ldtk.get_entities(level_name) or {}) do
        if (ENEMY_ENTITIES[entity.name] == true) == enemies then
            local x = rect.x + entity.position.x
            local y = rect.y + entity.position.y
            if entity.name == "PlayerStart" then
                self.levelStarts[level_name] = { x = x, y = y }
            else
                local spawn = entitySpawners[entity.name]
                if spawn then spawn(x, y, entity) end
            end
        end
    end
end

function GameScene:spawnEnemies(level_name)
    local rect = ldtk.get_rect(level_name)
    if not rect then return end
    local before = snapshotSprites()
    self:spawnEntities(level_name, rect, true)
    local sprites = spritesCreatedSince(before)
    local isRunning = self.runningLevels[level_name] == true
    for _, s in ipairs(sprites) do s:setUpdatesEnabled(isRunning) end
    self.enemySprites[level_name] = sprites
end

function GameScene:removeEnemies(level_name)
    local sprites = self.enemySprites[level_name]
    if not sprites then return end
    for _, s in ipairs(sprites) do s:remove() end
    self.enemySprites[level_name] = nil
end

-- Spawns enemies only if the level doesn't currently have any
function GameScene:ensureEnemies(level_name)
    if not self.enemySprites[level_name] then
        self:spawnEnemies(level_name)
    end
end


return GameScene
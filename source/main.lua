import "CoreLibs/graphics"
import "CoreLibs/object"
import "CoreLibs/timer"
import "player"

local gfx <const> = playdate.graphics
local TILE_SIZE = 16
local GROUND_Y = 200
local GROUND_TILE_Y = math.floor(GROUND_Y / TILE_SIZE)
local TILE_ORIGIN_Y = GROUND_Y % TILE_SIZE

local playerImage = gfx.image.new("images/Player_Date_Player_Test_2")
local player = Player.new(100, 200)

local function drawTile(x, y)
    gfx.drawRect(x, y, TILE_SIZE, TILE_SIZE)
end

local function drawGroundTiles()
    local tilesAcross = math.floor(400 / TILE_SIZE)

    -- Base ground row.
    for i = 0, tilesAcross - 1 do
        drawTile(i * TILE_SIZE, GROUND_Y)
    end

    -- Two adjacent stacks rising above the base row.
    local stackX = 224
    for i = 1, 4 do
        drawTile(stackX, GROUND_Y - i * TILE_SIZE)
    end
    for i = 1, 5 do
        drawTile(stackX + TILE_SIZE, GROUND_Y - i * TILE_SIZE)
    end
end

local function isSolidTileAt(tileX, tileY)
    -- Full base row.
    if tileY == GROUND_TILE_Y and tileX >= 0 and tileX < math.floor(400 / TILE_SIZE) then
        return true
    end

    -- Two adjacent columns above the base row.
    local stackTileX = math.floor(224 / TILE_SIZE)
    if tileX == stackTileX and tileY >= GROUND_TILE_Y - 4 and tileY <= GROUND_TILE_Y - 1 then
        return true
    end
    if tileX == stackTileX + 1 and tileY >= GROUND_TILE_Y - 5 and tileY <= GROUND_TILE_Y - 1 then
        return true
    end

    return false
end

local function isSolidAtPixel(x, y)
    local tileX = math.floor(x / TILE_SIZE)
    local tileY = math.floor((y - TILE_ORIGIN_Y) / TILE_SIZE)
    return isSolidTileAt(tileX, tileY)
end

Player.setCollisionQuery(isSolidAtPixel)

function playdate.update()
    gfx.clear()
    drawGroundTiles()
    Player.update(player)
    Player.draw(player, playerImage)
    playdate.timer.updateTimers()
end
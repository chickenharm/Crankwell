import "CoreLibs/graphics"
import "CoreLibs/object"
import "CoreLibs/timer"
import "CoreLibs/sprites"
import "player"

local gfx <const> = playdate.graphics

-- Creating a tags object, to keep track of tags more easily
TAGS = {
    player = 1,
    obstacle = 2,
    coin = 3,
    powerUp = 4
}

-- player stuff --
local playerImage = gfx.image.new("images/Player_Date_Player_Test_2")
local player = Player.new(100, 200)

gfx.pushContext(playerImage)
gfx.popContext()
local playerSprite = playdate.graphics.sprite.new(playerImage)
playerSprite:setTag(TAGS.player)
playerSprite:moveTo(100, 184)
playerSprite:setCollideRect(0, 0, playerSprite:getSize())
playerSprite:add()

-- obstacle stuff --

local TILE_SIZE = 16
local GROUND_Y = 200

local function createObstacleSprite(width, height, x, y, color)
    local obstacleImage = playdate.graphics.image.new(width, height, color)
    local obstacleSprite = gfx.sprite.new(obstacleImage)
    obstacleSprite:setTag(TAGS.obstacle)
    obstacleSprite:moveTo(x, y)
    obstacleSprite: setCollideRect(0, 0, obstacleSprite:getSize())
    obstacleSprite:add()
end

local function createTiles()
    local tileLength = math.floor(400 / TILE_SIZE)

    for i = 0, tileLength - 1 do
        createObstacleSprite(TILE_SIZE, TILE_SIZE, i * TILE_SIZE, GROUND_Y, gfx.kColorBlack)
    end

    local stackX = 224
    for i = 1, 4 do
        createObstacleSprite(TILE_SIZE, TILE_SIZE, stackX, GROUND_Y - i * TILE_SIZE, gfx.kColorBlack)
    end
    for i = 1, 5 do
        createObstacleSprite(TILE_SIZE, TILE_SIZE, stackX, GROUND_Y - i * TILE_SIZE, gfx.kColorBlack)
    end
end 


-- MAIN LOOP --

function playdate.update()
    gfx.clear()
    createTiles()
    gfx.sprite.update()
    --drawGroundTiles()
    Player.update(player, playerSprite)
    -- Player.draw(player, playerImage)
    gfx.drawLine(0, 200, 400, 200)
    playdate.timer.updateTimers()
end
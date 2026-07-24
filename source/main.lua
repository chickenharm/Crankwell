import "CoreLibs/graphics"
import "CoreLibs/object"
import "CoreLibs/timer"
import "CoreLibs/sprites"
import "player"

local gfx <const> = playdate.graphics

local SCREEN_WIDTH = 400

-- Creating a tags object, to keep track of tags more easily
TAGS = {
    player = 1,
    obstacle = 2,
    coin = 3,
    powerUp = 4
}

playdate.clearConsole()


-- player stuff --
local playerImage = gfx.image.new("images/Player_Date_Player_Test_2")
local player = Player.new(100, 184)

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
local GROUND_TILE_CENTER_Y = GROUND_Y + (TILE_SIZE / 2)

local function createObstacleSprite(width, height, x, y, color)
    local obstacleImage = playdate.graphics.image.new(width, height, color)
    local obstacleSprite = gfx.sprite.new(obstacleImage)
    obstacleSprite:setTag(TAGS.obstacle)
    obstacleSprite:moveTo(x, y)
    obstacleSprite: setCollideRect(0, 0, obstacleSprite:getSize())
    obstacleSprite:add()
end

local function createTiles()
    -- Use one continuous floor collider to avoid horizontal stutter on tile seams.
    createObstacleSprite(SCREEN_WIDTH, TILE_SIZE, SCREEN_WIDTH / 2, GROUND_TILE_CENTER_Y, gfx.kColorBlack)

    local stackX = 224
    for i = 1, 4 do
        local stackCenterY = GROUND_TILE_CENTER_Y - (i * TILE_SIZE)
        createObstacleSprite(TILE_SIZE, TILE_SIZE, stackX, stackCenterY, gfx.kColorBlack)
    end
end 

    createTiles()


-- MAIN LOOP --

function playdate.update()
    gfx.clear()
    Player.update(player, playerSprite)
    gfx.sprite.update()
    gfx.drawLine(0, 200, 400, 200)
    playdate.timer.updateTimers()
end
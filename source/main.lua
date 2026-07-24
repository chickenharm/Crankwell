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
playerSprite:moveTo(200, 120)
playerSprite:setCollideRect(0, 0, playerSprite:getSize())
playerSprite:add()


-- obstacle stuff --

local TILE_SIZE = 16
local GROUND_Y = 200


local function drawTile(x, y)
    gfx.drawRect(x, y, TILE_SIZE, TILE_SIZE)
end

local obstacleImage = drawTile(TILE_SIZE, GROUND_Y)
local obstacleSprite = gfx.sprite.new(obstacleImage)

obstacleSprite:setTag(TAGS.obstacle)
obstacleSprite:moveTo(300, 120)
obstacleSprite: setCollideRect(0, 0, obstacleSprite:getSize())
obstacleSprite:add()


local function drawGroundTiles()
    local tileLength = math.floor(400 / TILE_SIZE)

    -- ground row --
    for i = 0, tileLength - 1 do
        drawTile(i * TILE_SIZE, GROUND_Y)
    end

    local stackX = 224
    for i = 1, 4 do
        drawTile(stackX, GROUND_Y - i * TILE_SIZE)
    end
    for i = 1, 5 do
        drawTile(stackX + TILE_SIZE, GROUND_Y - i * TILE_SIZE)
    end
end

    

function playdate.update()
    gfx.clear()
    gfx.sprite.update()
    

    --drawGroundTiles()
    Player.update(player, playerSprite)
    -- Player.draw(player, playerImage)
    gfx.drawLine(0, 200, 400, 200)
    playdate.timer.updateTimers()
end
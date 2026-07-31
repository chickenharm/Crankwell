import "CoreLibs/graphics"
import "CoreLibs/object"
import "CoreLibs/timer"
import "CoreLibs/sprites"
import "player"
import "CoreLibs/animation"

import "scripts/libraries/LDtk"

local gfx <const> = playdate.graphics
local SCREEN_WIDTH = 400
local WORLD_WIDTH = 1200

local cameraX = 0

-- Creating a tags object, to keep track of tags more easily
TAGS = {
   player = 1,
   obstacle = 2,
   coin = 3,
   powerUp = 4
}

playdate.clearConsole()

-- player animation stuff
local idleFrames = {
   gfx.image.new("images/Fox/Idle/Player_Idle_1"),
   gfx.image.new("images/Fox/Idle/Player_Idle_2"),
   gfx.image.new("images/Fox/Idle/Player_Idle_3")
}

local runFrames = {
   gfx.image.new("images/Fox/Run/Run1"),
   gfx.image.new("images/Fox/Run/Run2"),
   gfx.image.new("images/Fox/Run/Run3"),
   gfx.image.new("images/Fox/Run/Run4")
}

local jumpFrames = {
   gfx.image.new("images/Fox/Jump/Fox_Jump_1"),
   gfx.image.new("images/Fox/Jump/Fox_Jump_2")
}

local flutterFrames = {
    gfx.image.new("images/Fox/Flutter/Fox_Flutter_1"),
    gfx.image.new("images/Fox/Flutter/Fox_Flutter_2"),
    gfx.image.new("images/Fox/Flutter/Fox_Flutter_3")
}


-- create player
local playerImage = gfx.image.new("images/Fox/Idle/Player_Idle_1")
if not playerImage then
   -- Visible fallback so the player never disappears when an asset fails to load.
   
   playerImage = gfx.image.new(32, 32, gfx.kColorBlack)
end
local player = Player.new(100, 184, {
    frames = {
        idle = idleFrames,
        run = runFrames,
        jump = jumpFrames,
        flutter = flutterFrames
    },
    msByState = {
        idle = 180,
        run = 90,
        jump = 140,
        flutter = 45
    }
})


-- set player animation
player.frames = {
   idle = idleFrames,
   run = runFrames,
   jump = jumpFrames
}

player.animState = "idle"
player.animFrame = 1
player.animTimer = 0


-- set up player collision and other stuff
gfx.pushContext(playerImage)
gfx.popContext()
local playerSprite = playdate.graphics.sprite.new(playerImage)
playerSprite:setTag(TAGS.player)
playerSprite:moveTo(100, 184)
-- playerSprite:setCollideRect(0, 0, player.width, player.height)
local imageW, imageH = playerSprite:getSize()
local hitboxX = math.floor((imageW - player.width) / 2)
local hitboxY = imageH - player.height
playerSprite:setCollideRect(hitboxX, hitboxY, player.width, player.height)
playerSprite:add()

function playerSprite:collisionResponse(other)
   if other:getTag() == TAGS.obstacle then
       return gfx.sprite.kCollisionTypeSlide
   end
   return gfx.sprite.kCollisionTypeOverlap
end

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
   createObstacleSprite(WORLD_WIDTH, TILE_SIZE, SCREEN_WIDTH / 2, GROUND_TILE_CENTER_Y, gfx.kColorBlack)

   local stackX = 224
   for i = 1, 4 do
       local stackCenterY = GROUND_TILE_CENTER_Y - (i * TILE_SIZE)
       createObstacleSprite(TILE_SIZE, TILE_SIZE, stackX, stackCenterY, gfx.kColorBlack)
   end
end

createTiles()

-- draws a collision box for debug
local function drawCollideRect(sprite)
   local bx, by, bw, bh = sprite:getBounds()          -- world-space sprite bounds
   local cx, cy, cw, ch = sprite:getCollideBounds()   -- collide rect, relative to sprite
   gfx.drawRect(bx + cx, by + cy, cw, ch)
end

function playdate.debugDraw()
   drawCollideRect(playerSprite)
end

-- call animation loop
player.animLoop = gfx.animation.loop.new(200, idleFrames, true)


-- MAIN LOOP
function playdate.update()
   gfx.clear()
   Player.update(player, playerSprite, idleFrames)
   gfx.sprite.update()
   Player.draw(player) -- bar/HUD only
   gfx.drawLine(0, 200, 400, 200)
   playdate.timer.updateTimers()
end


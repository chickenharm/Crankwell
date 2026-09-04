import "CoreLibs/graphics"
import "CoreLibs/object"
import "CoreLibs/timer"
import "CoreLibs/sprites"
import "CoreLibs/animation"

import "scripts/libraries/LDtk"
import "scripts/libraries/AnimatedSprite"
import "player"


local GameScene = import "scripts/GameScene"
GameScene:init()

local gfx <const> = playdate.graphics

local SCREEN_WIDTH = 400
local WORLD_WIDTH = 1200

local cameraX = 0

local FLUTTER_FUEL_MAX = 40

local DEBUG = false


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

-- MAIN LOOP
function playdate.update()
   gfx.sprite.update()
   GameScene:updateCamera()

   gfx.pushContext()
   gfx.setDrawOffset(0, 0)

   playdate.timer.updateTimers()

    gfx.drawRect(10, 10, 100, 8)
    gfx.fillRect(
        10,
        10,
        100 * (GameScene.player.flutterFuel / FLUTTER_FUEL_MAX),
        8
    )
gfx.popContext()
    if GameScene.player.fluttering then
      gfx.drawText("FLUTTER", 10, 25)
    end

    -- debug to check if player grounded
     if DEBUG then
        local player = GameScene.player
        gfx.setColor(gfx.kColorXOR)
        gfx.drawRect(player.x - 6, player.y - 10, 17, 25) -- matches setCollideRect(5,5,12,20) offset from player.x/y
        gfx.drawText("grounded: " .. tostring(player.grounded), 5, 15)
    end
end



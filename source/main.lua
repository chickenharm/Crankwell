import "CoreLibs/graphics"
import "CoreLibs/object"
import "CoreLibs/timer"
import "CoreLibs/sprites"
import "CoreLibs/animation"

import "scripts/libraries/LDtk"
import "scripts/libraries/AnimatedSprite"
import "player"

import "scripts/spike"
import "scripts/spikeBall"


local GameScene = import "scripts/GameScene"
GameScene:init()

local gfx <const> = playdate.graphics

local FLUTTER_FUEL_MAX = 40

local DEBUG = true

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

   playdate.timer.updateTimers()

   -- world-space debug overlay: draw while the camera's draw offset is still active
   if DEBUG then
      local player = GameScene.player
      gfx.setColor(gfx.kColorXOR)
      gfx.drawRect(player.x - 6, player.y - 10, 17, 25) -- matches setCollideRect(5,5,12,20) offset from player.x/y
   end

   gfx.pushContext()
   gfx.setDrawOffset(0, 0)

   gfx.drawRect(10, 10, 100, 8)
   gfx.fillRect(
       10,
       10,
       100 * (GameScene.player.flutterFuel / FLUTTER_FUEL_MAX),
       8
   )

   if GameScene.player.fluttering then
      gfx.drawText("FLUTTER", 10, 25)
   end

   if DEBUG then
      local player = GameScene.player
      gfx.drawText("grounded: " .. tostring(player.grounded), 5, 55)
      gfx.drawText("fuel: " .. tostring(player.flutterFuel), 5, 70)
      gfx.drawText("crank: " .. tostring(playdate.getCrankChange and playdate.getCrankChange() or "?"), 5, 85)
   end

   gfx.popContext()
end



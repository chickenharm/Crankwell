import "CoreLibs/graphics"
import "CoreLibs/object"
import "CoreLibs/timer"
import "player"

local gfx <const> = playdate.graphics

local playerImage = gfx.image.new("images/player")
local player = Player.new(100, 200)

function playdate.update()
    gfx.clear()
    Player.update(player)
    Player.draw(player, playerImage)
    gfx.drawLine(0, 200, 400, 200)
    playdate.timer.updateTimers()
end
-- player.lua
import "CoreLibs/graphics"

local gfx <const> = playdate.graphics

-- Constants
local GRAVITY = 0.8
local JUMP_VELOCITY = -10
local MAX_FALL_SPEED = 12
local GROUND_Y = 200
local FLUTTER_GRAVITY = 0.15
local FLUTTER_START_BOOST = -.5 -- slight upward kick when flutter starts
local CRANK_SPEED_THRESHOLD = 12
local FLUTTER_FUEL_MAX = 20
local FLUTTER_FUEL_REGEN_ON_LAND = true
local MOVE_SPEED = 3

Player = {}

function Player.new(x, y)
    return {
        x = x or 100,
        y = y or GROUND_Y,
        vy = 0,
        width = 16,
        height = 16,
        grounded = true,
        fluttering = false,
        flutterFuel = FLUTTER_FUEL_MAX,
        direction = 1  -- 1 for right, -1 for left
    }
end


local function isCrankingFast()
    local change = playdate.getCrankChange()
    return math.abs(change) > CRANK_SPEED_THRESHOLD
end

function Player.update(player)
    local wasFluttering = player.fluttering

     if playdate.buttonIsPressed(playdate.kButtonLeft) then
        player.x -= MOVE_SPEED
        player.direction = -1
    elseif playdate.buttonIsPressed(playdate.kButtonRight) then
        player.x += MOVE_SPEED
        player.direction = 1
    end

    if player.x < 0 then
        player.x = 0
    elseif player.x > 400 - player.width then
        player.x = 400 - player.width
    end

    if playdate.buttonJustPressed(playdate.kButtonUp) and player.grounded then
        player.vy = JUMP_VELOCITY
        player.grounded = false
    end

    if not player.grounded and player.flutterFuel > 0 and isCrankingFast() then
        player.fluttering = true
    else
        player.fluttering = false
    end

    -- Apply a small impulse only on the transition into fluttering
    if player.fluttering and not wasFluttering then
        player.vy += FLUTTER_START_BOOST
    end

    if player.fluttering then
        player.vy += FLUTTER_GRAVITY
        player.flutterFuel -= 1
    else
        player.vy += GRAVITY
    end

    if player.vy > MAX_FALL_SPEED then
        player.vy = MAX_FALL_SPEED
    end

    player.y += player.vy

    if player.y >= GROUND_Y then
        player.y = GROUND_Y
        player.vy = 0
        if not player.grounded and FLUTTER_FUEL_REGEN_ON_LAND then
            player.flutterFuel = FLUTTER_FUEL_MAX
        end
        player.grounded = true
        player.fluttering = false
    end
end


function Player.draw(player, playerImage)
    -- Draw sprite flipped based on direction
    -- direction 1 = normal, -1 = flipped horizontally
    playerImage:drawScaled(player.x, player.y - player.height, player.direction, 1)
    
    gfx.drawRect(10, 10, 100, 8)
    gfx.fillRect(10, 10, 100 * (player.flutterFuel / FLUTTER_FUEL_MAX), 8)
    if player.fluttering then
        gfx.drawText("FLUTTER", 10, 25)
    end
end
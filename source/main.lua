-- Flutter Jump Platformer - starter scaffold
-- Mechanic: press Up to jump. While airborne, crank fast to "flutter" (reduced
-- gravity + slight lift) for a limited fuel duration, similar to Yoshi's Island.

import "CoreLibs/graphics"
import "CoreLibs/object"
import "CoreLibs/timer"

local gfx <const> = playdate.graphics

-- ===== Tunable constants =====
local GRAVITY = 0.8
local JUMP_VELOCITY = -10
local MAX_FALL_SPEED = 12
local GROUND_Y = 200

local FLUTTER_GRAVITY = 0.15       -- much lower gravity while fluttering (this alone creates the "hang")
local CRANK_SPEED_THRESHOLD = 12   -- degrees/frame to count as "cranking fast"
local FLUTTER_FUEL_MAX = 30        -- frames of flutter available per airtime
local FLUTTER_FUEL_REGEN_ON_LAND = true
local MOVE_SPEED = 3               -- pixels per frame while holding left/right

-- ===== Sprite loading =====
local TILE_SIZE = 16 -- adjust to match your tilemap's actual cell size

-- Crops a single tile out of a larger sheet image.
-- col/row are 0-indexed (0,0 = top-left cell).
local function getTileFromSheet(sheet, col, row, tileSize)
    local tile = gfx.image.new(tileSize, tileSize)
    gfx.pushContext(tile)
        sheet:draw(-col * tileSize, -row * tileSize)
    gfx.popContext()
    return tile
end

local tilemapImage = gfx.image.new("images/monochrome_tilemap")
local playerImage = getTileFromSheet(tilemapImage, 1, 13, TILE_SIZE)

-- ===== Player state =====
local player = {
    x = 100,
    y = GROUND_Y,
    vy = 0,
    width = 16,
    height = 16,
    grounded = true,
    fluttering = false,
    flutterFuel = FLUTTER_FUEL_MAX
}

local function isCrankingFast()
    local change = playdate.getCrankChange()
    return math.abs(change) > CRANK_SPEED_THRESHOLD
end

local function updatePlayer()
    -- Horizontal movement (held, not just-pressed, so it moves continuously)
    if playdate.buttonIsPressed(playdate.kButtonLeft) then
        player.x -= MOVE_SPEED
    elseif playdate.buttonIsPressed(playdate.kButtonRight) then
        player.x += MOVE_SPEED
    end

    -- Keep player on screen (simple clamp, remove once you have real level bounds)
    if player.x < 0 then
        player.x = 0
    elseif player.x > 400 - player.width then
        player.x = 400 - player.width
    end

    -- Jump input
    if playdate.buttonJustPressed(playdate.kButtonUp) and player.grounded then
        player.vy = JUMP_VELOCITY
        player.grounded = false
    end

    -- Decide flutter state (only possible while airborne and fuel remains)
    if not player.grounded and player.flutterFuel > 0 and isCrankingFast() then
        player.fluttering = true
    else
        player.fluttering = false
    end

    -- Apply physics
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

    -- Ground collision (simple flat floor for now)
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

local function drawPlayer()
    playerImage:draw(player.x, player.y - player.height)

    -- Debug: flutter fuel bar
    gfx.drawRect(10, 10, 100, 8)
    gfx.fillRect(10, 10, 100 * (player.flutterFuel / FLUTTER_FUEL_MAX), 8)

    if player.fluttering then
        gfx.drawText("FLUTTER", 10, 25)
    end
end

function playdate.update()
    gfx.clear()
    updatePlayer()
    drawPlayer()
    gfx.drawLine(0, GROUND_Y + player.height, 400, GROUND_Y + player.height)
    playdate.timer.updateTimers()
end

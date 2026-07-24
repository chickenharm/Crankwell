-- player.lua --
import "CoreLibs/graphics"

local gfx <const> = playdate.graphics

-- Constants
local GRAVITY = 0.8
local JUMP_VELOCITY = -10
local MAX_FALL_SPEED = 12
local GROUND_Y = 184
local FLUTTER_GRAVITY = 0.15
local FLUTTER_START_BOOST = -.5 -- slight upward kick when flutter starts
local CRANK_SPEED_THRESHOLD = 12
local FLUTTER_FUEL_MAX = 20
local FLUTTER_FUEL_REGEN_ON_LAND = true
local MOVE_SPEED = 3
local MAX_RISE_SPEED = -3.5

-- Add near other constants
local APEX_GLIDE_GRAVITY = 0.08
local APEX_GLIDE_DURATION = 5         -- frames
local APEX_VELOCITY_WINDOW = 1.0       -- "near zero" vertical speed
local APEX_CANCEL_HORIZONTAL_SPEED = 1.5 -- cancel apex glide if player moves too fast sideways

Player = {}

function Player.new(x, y)
  return {
      x = x or 100,
      y = y or GROUND_Y,
      vy = 0,
      vx = 0,
      width = 32,
      height = 32,
      grounded = true,
      fluttering = false,
      flutterFuel = FLUTTER_FUEL_MAX,
      direction = 1, -- 1 for right, -1 for left

      -- apex glide stuff
      apexGliding = false,
      apexGlideTimer = 0
  }
end

local function isCrankingFast()
  local change = playdate.getCrankChange()
  return math.abs(change) > CRANK_SPEED_THRESHOLD
end

function Player.update(player, playerSprite)
    local wasGrounded = player.grounded
    local wasFluttering = player.fluttering
    local prevVy = player.vy

    player.vx = 0
    if playdate.buttonIsPressed(playdate.kButtonLeft) then
        player.vx = -MOVE_SPEED
        player.direction = -1
    elseif playdate.buttonIsPressed(playdate.kButtonRight) then
        player.vx = MOVE_SPEED
        player.direction = 1
    end

    if playdate.buttonJustPressed(playdate.kButtonUp) and player.grounded then
        player.vy = JUMP_VELOCITY
        player.grounded = false
    end

    player.fluttering = (not player.grounded) and player.flutterFuel > 0 and isCrankingFast()

    if player.fluttering and not wasFluttering then
        player.vy += FLUTTER_START_BOOST
    end

    if (not player.grounded)
            and (not player.fluttering)
            and (prevVy < 0)
            and (math.abs(player.vy) <= APEX_VELOCITY_WINDOW)
            and (math.abs(player.vx) <= APEX_CANCEL_HORIZONTAL_SPEED)
            and player.apexGlideTimer <= 0 then
        player.apexGliding = true
        player.apexGlideTimer = APEX_GLIDE_DURATION
    end

    if player.apexGliding and math.abs(player.vx) > APEX_CANCEL_HORIZONTAL_SPEED then
        player.apexGliding = false
        player.apexGlideTimer = 0
    end

    if player.fluttering then
        player.vy += FLUTTER_GRAVITY
        player.flutterFuel -= 1
    elseif player.apexGliding and player.apexGlideTimer > 0 then
        player.vy += APEX_GLIDE_GRAVITY
        player.apexGlideTimer -= 1
        if player.apexGlideTimer <= 0 then
            player.apexGliding = false
        end
    elseif (not player.grounded) or player.vy < 0 then
        player.vy += GRAVITY
    else
        player.vy = 0
    end

    if player.fluttering then
        player.vy = math.max(player.vy, MAX_RISE_SPEED)
    end

    if player.vy > MAX_FALL_SPEED then
        player.vy = MAX_FALL_SPEED
    end

    local halfWidth = player.width / 2
    local goalX = playerSprite.x + player.vx
    local goalY = playerSprite.y + player.vy
    goalX = math.max(halfWidth, math.min(400 - halfWidth, goalX))

    local actualX, actualY, collisions, numberOfCollisions =
            playerSprite:moveWithCollisions(goalX, goalY)

    player.grounded = false
    for i = 1, numberOfCollisions do
        local c = collisions[i]
        if c.other:getTag() == TAGS.obstacle then
            if c.normal.y == -1 then
                player.grounded = true
                player.vy = 0
            elseif c.normal.y == 1 then
                player.vy = 0
            end
            if c.normal.x ~= 0 then
                player.vx = 0
            end
        end
    end

    if player.grounded then
        if (not wasGrounded) and FLUTTER_FUEL_REGEN_ON_LAND then
            player.flutterFuel = FLUTTER_FUEL_MAX
        end
        player.fluttering = false
        player.apexGliding = false
        player.apexGlideTimer = 0
    end

    if player.flutterFuel < 0 then
        player.flutterFuel = 0
    end

    player.x = actualX
    player.y = actualY
end


function Player.draw(player, playerImage)
  -- Draw sprite flipped based on direction
  -- direction 1 = normal, -1 = flipped horizontally
  -- playerImage:drawScaled(player.x, player.y - player.height, player.direction, 1)
    gfx.drawRect(10, 10, 100, 8)
    gfx.fillRect(10, 10, 100 * (player.flutterFuel / FLUTTER_FUEL_MAX), 8)
    if player.fluttering then
      gfx.drawText("FLUTTER", 10, 25)
  end
end




-- player.lua --
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

  local wasFluttering = player.fluttering
  local prevVy = player.vy
  player.vx = 0
  
  local goalX, goalY = playerSprite.x, playerSprite.y


  if playdate.buttonIsPressed(playdate.kButtonLeft) then
    --player.x -= MOVE_SPEED
    --player.vx = -MOVE_SPEED
    goalX -= MOVE_SPEED

      player.direction = -1
  elseif playdate.buttonIsPressed(playdate.kButtonRight) then
    --player.x += MOVE_SPEED
    --player.vx = MOVE_SPEED
    goalX += MOVE_SPEED

      player.direction = 1
  end

    if playdate.buttonJustPressed(playdate.kButtonUp) and player.grounded then
        goalY -= JUMP_VELOCITY
        --player.vy = JUMP_VELOCITY
      player.grounded = false
  end

  if not player.grounded and player.flutterFuel > 0 and isCrankingFast() then
      player.fluttering = true
  else
      player.fluttering = false
  end

  if not player.grounded and player.flutterFuel > 0 and isCrankingFast() then
      player.fluttering = true
  else
      player.fluttering = false
  end

  if player.fluttering and not wasFluttering then
      player.vy += FLUTTER_START_BOOST
  end

  if player.x < 0 then
      player.x = 0
  elseif player.x > 400 - player.width then
      player.x = 400 - player.width
  end


  local actualX, actualY, collisions, numberOfCollisions = playerSprite:moveWithCollisions(goalX, goalY)

  for i = 1, numberOfCollisions do
    local collision = collisions[i]

    print(collisions.sprite == playerSprite)
    print(collision.sprite:getTag() == TAGS.player)

    local collidedSprite = collision.other
    local collisionTag = collidedSprite:getTag()

    if collisionTag == TAGS.obstacle then
        print("Collided with an obstacle!")
        -- check which side the sprite collided on   
        local collisionNormal = collision.normal
        if collisionNormal.x == -1 then
            print("Touched left side!")
        elseif collisionNormal.x == 1 then
            print("Touched right side!")
        end

        if collisionNormal.y == -1 then
            print("touched top!")
        elseif collisionNormal.y == 1 then
            print("touched bottom")
        end

    elseif collisionTag == TAGS.coin then
        print("Coin collect")
    elseif collisionTag == TAGS.powerUp then
        print("power up!")
    end

  end



     -- Detect entering apex zone
  if (not player.grounded)
      and (not player.fluttering)
      and (prevVy < 0)
      and (math.abs(player.vy) <= APEX_VELOCITY_WINDOW)
      and (math.abs(player.vx) <= APEX_CANCEL_HORIZONTAL_SPEED) -- only allow if not moving too fast sideways
      and player.apexGlideTimer <= 0 then
      player.apexGliding = true
      player.apexGlideTimer = APEX_GLIDE_DURATION
  end

  -- Cancel active apex glide if horizontal speed too high
  if player.apexGliding and math.abs(player.vx) > APEX_CANCEL_HORIZONTAL_SPEED then
      player.apexGliding = false
      player.apexGlideTimer = 0
  end


  -- Gravity selection
  if player.fluttering then
      player.vy += FLUTTER_GRAVITY
      player.flutterFuel -= 1
  elseif player.apexGliding and player.apexGlideTimer > 0 then
      player.vy += APEX_GLIDE_GRAVITY
      player.apexGlideTimer -= 1
      if player.apexGlideTimer <= 0 then
          player.apexGliding = false
      end
  else
      player.vy += GRAVITY
  end

  if player.fluttering then
      player.vy = math.max(player.vy, MAX_RISE_SPEED)
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
      player.apexGliding = false
      player.apexGlideTimer = 0
  else
      player.grounded = false
  end
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




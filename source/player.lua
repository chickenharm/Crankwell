-- player.lua --
import "CoreLibs/graphics"

local gfx <const> = playdate.graphics

-- Constants
local GRAVITY = 0.8
local JUMP_VELOCITY = -10
local MAX_FALL_SPEED = 12
local GROUND_Y = 184
local CRANK_SPEED_THRESHOLD = 12

-- jump buffer and coyote time
local JUMP_BUFFER_FRAMES = 6
local COYOTE_FRAMES = 6

-- horizontal movement
local ACCEL = 0.8
local FRICTION = 0.7
local MAX_RUN_SPEED = 3

-- flutter stuff
local FLUTTER_FUEL_MAX = 40
local FLUTTER_FUEL_REGEN_ON_LAND = true
local FLUTTER_APEX_HOLD_FRAMES = 3
local FLUTTER_LIFT_PIXELS = 32
local FLUTTER_LIFT_SPEED = -1.0
local FLUTTER_DROP_PIXELS = 16
local FLUTTER_DROP_SPEED = 2.4

-- animation stuff
local ANIMATION_FRAME_DELAY = 20

Player = {}

function Player.new(x, y)
return {
    x = x or 100,
    y = y or GROUND_Y,
    vy = 0,
    vx = 0,
    width = 21,
    height = 19,
    grounded = true,
    fluttering = false,
    flutterFuel = FLUTTER_FUEL_MAX,
    direction = 1, -- 1 for right, -1 for left

    -- apex glide stuff
    apexGliding = false,
    apexGlideTimer = 0,
    -- jump buffer & coyote time
    jumpBufferTimer = 0,
    coyoteTimer = 0,
   -- flutter stuff
    flutterApexHoldTimer = 0,
    flutterLiftRemaining = 0,
    flutterSequenceDone = false,
    flutterDropRemaining = 0
}
end


-- animation logic
local function chooseAnimState(player)
   if not player.grounded then
       return "jump"
   elseif math.abs(player.vx) > 0.1 then
       return "run"
   else
       return "idle"
   end
end


local function updateAnimation_Custom(player, sprite)
   local state = chooseAnimState(player)

   if state ~= player.animState then
       player.animState = state
       player.animFrame = 1
       player.animTimer = 0
   end

   player.animTimer += 1
   if player.animTimer >= ANIMATION_FRAME_DELAY then
       player.animTimer = 0
       local frames = player.frames[player.animState]
       player.animFrame = (player.animFrame % #frames) + 1
   end
   
   local frame = player.frames[player.animState][player.animFrame]
   local flip = player.direction == -1 and gfx.kImageFlippedX or gfx.kImageUnflipped
   sprite:setImage(frame, flip)
end

local function animatePlayer(player, playerSprite, idleFrames)
    local frameTime = 200
    local animationImageTable = idleFrames
    local animationLoop = gfx.animation.loop.new(frameTime, animationImageTable, false)
    local animatedSprite = gfx.sprite.new(animationLoop:image())
    animatedSprite:add()
    animatedSprite.update = function()
        animatedSprite:setImage(animationLoop:image())
    end
end

local function updateAnimation(player, playerSprite)
  local flip = player.direction == -1 and gfx.kImageFlippedX or gfx.kImageUnflipped
  playerSprite:setImage(player.animLoop:image(), flip)
end

local function isCrankingFast()
   local change = playdate.getCrankChange()
   return math.abs(change) > CRANK_SPEED_THRESHOLD
end


local function updateFlutterState(player, prevVy)
   player.fluttering = (not player.grounded) and player.flutterFuel > 0 and isCrankingFast()


   if not player.fluttering then
       player.flutterDropRemaining = 0
       player.flutterApexHoldTimer = 0
       player.flutterLiftRemaining = 0
   end


   local atApexTransition = prevVy < 0 and (prevVy + GRAVITY) >= 0


   if player.fluttering
       and (not player.flutterSequenceDone)
       and atApexTransition then
       player.flutterDropRemaining = FLUTTER_DROP_PIXELS
       player.flutterApexHoldTimer = 0
       player.flutterLiftRemaining = FLUTTER_LIFT_PIXELS
   end


   -- Phase 1: short drop
   if player.flutterDropRemaining > 0 and player.fluttering then
       player.vy = FLUTTER_DROP_SPEED
       player.flutterDropRemaining -= FLUTTER_DROP_SPEED
       player.flutterFuel -= 1


       if player.flutterDropRemaining <= 0 then
           player.flutterDropRemaining = 0
           player.flutterApexHoldTimer = FLUTTER_APEX_HOLD_FRAMES
       end


   -- Phase 2: hold position
   elseif player.flutterApexHoldTimer > 0 then
       player.vy = 0
       player.flutterApexHoldTimer -= 1


   -- Phase 3: move up
   elseif player.flutterLiftRemaining > 0 and player.fluttering then
       player.vy = FLUTTER_LIFT_SPEED
       player.flutterLiftRemaining -= math.abs(FLUTTER_LIFT_SPEED)
       player.flutterFuel -= 1


       if player.flutterLiftRemaining <= 0 then
           player.flutterLiftRemaining = 0
           player.flutterSequenceDone = true
       end


   elseif (not player.grounded) or player.vy < 0 then
       player.vy += GRAVITY
   else
       player.vy = 0
   end
end


-- horizontal movement
local function updateHorizontalMovement(player)
   if playdate.buttonIsPressed(playdate.kButtonLeft) then
       player.vx = math.max(player.vx - ACCEL, -MAX_RUN_SPEED)
       player.direction = -1
   elseif playdate.buttonIsPressed(playdate.kButtonRight) then
       player.vx = math.min(player.vx + ACCEL, MAX_RUN_SPEED)
       player.direction = 1
   else
       player.vx = player.vx * FRICTION
       if math.abs(player.vx) < 0.05 then
           player.vx = 0
       end
   end
end


-- jump logic
local function checkForJump(player)
   if playdate.buttonJustPressed(playdate.kButtonUp) then
      player.jumpBufferTimer = JUMP_BUFFER_FRAMES
       player.flutterDropRemaining = 0
  elseif player.jumpBufferTimer > 0 then
      player.jumpBufferTimer -= 1
  end
end

-- consume jump buffer
local function checkForConsumeJump(player)
  if player.jumpBufferTimer > 0 and (player.grounded or player.coyoteTimer > 0) then
      player.vy = JUMP_VELOCITY
      player.grounded = false
      player.jumpBufferTimer = 0
      player.coyoteTimer = 0
      player.fluttering = false
      player.flutterApexHoldTimer = 0
      player.flutterLiftRemaining = 0
      player.flutterSequenceDone = false
  end
end

-- player fall logic
local function handlePlayerFall(player)
      if player.vy > MAX_FALL_SPEED then
      player.vy = MAX_FALL_SPEED
  end
end

-- coyote time logic
local function checkForCoyoteTime(player)
    if player.grounded then
      player.coyoteTimer = COYOTE_FRAMES
  elseif player.coyoteTimer > 0 then
      player.coyoteTimer -= 1
  end
end

local function onLanding(player, wasGrounded)
      if player.grounded then
      if (not wasGrounded) and FLUTTER_FUEL_REGEN_ON_LAND then
          player.flutterFuel = FLUTTER_FUEL_MAX
      end
      player.fluttering = false
      player.flutterApexHoldTimer = 0
      player.flutterLiftRemaining = 0
      player.flutterSequenceDone = false
      player.apexGliding = false
      player.apexGlideTimer = 0
      player.flutterDropRemaining = 0
  end
end


local function updateFlutterFuel(player)
    if player.flutterFuel < 0 then
      player.flutterFuel = 0
  end
end


local function resolveMovementAndCollisions(player, playerSprite, wasGrounded)
   local halfWidth = player.width / 2
   local goalX = playerSprite.x + player.vx
   local goalY = playerSprite.y + player.vy
   goalX = math.max(halfWidth, math.min(400 - halfWidth, goalX))

   local _, _, collideW, collideH = playerSprite:getCollideBounds()
   if collideW <= 0 or collideH <= 0 then
       playerSprite:setCollideRect(0, 0, player.width, player.height)
   end


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
   player.x = actualX
   player.y = actualY
end




function Player.update(player, playerSprite, idleFrames)
  local wasGrounded = player.grounded
  local prevVy = player.vy

   --horizontal movement
   updateHorizontalMovement(player)

  -- player jump
  checkForJump(player)

  -- Update coyote timer from previous grounded state
  checkForCoyoteTime(player)

  -- Consume buffered jump if allowed
   checkForConsumeJump(player)

  -- check for flutter
  updateFlutterState(player, prevVy)

  -- check if player is falling
  handlePlayerFall(player)

  --handle collisions and movement
  resolveMovementAndCollisions(player, playerSprite, wasGrounded)
 
  -- call landing functions
  onLanding(player, wasGrounded)
 
  -- update flutter fuel
  updateFlutterFuel(player)
  
  -- call animation loops
  updateAnimation(player, playerSprite)

end

function Player.draw(player, playerImage)
  gfx.drawRect(10, 10, 100, 8)
  gfx.fillRect(10, 10, 100 * (player.flutterFuel / FLUTTER_FUEL_MAX), 8)
  if player.fluttering then
    gfx.drawText("FLUTTER", 10, 25)
end
end


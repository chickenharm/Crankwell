import "scripts/player/playerFlutter"

local pd <const> = playdate
local gfx <const> = playdate.graphics

--- @class Player : AnimatedSprite
Player = {}
class('Player').extends(AnimatedSprite)

-- Constants
local CRANK_SPEED_THRESHOLD = 3

-- Apex glide properties
local APEX_GLIDE_HOLD_FRAMES = 3

-- Fall properties
local MAX_FALL_SPEED = 12
local RISE_GRAVITY = 0.5
local FALL_GRAVITY = 1.1
local JUMP_VELOCITY = -7.1
local JUMP_CUT_VELOCITY = -2.5 -- max upward speed once the jump button is released

-- Coyote properties
local COYOTE_FRAMES = 6

-- jump properties
local SLAM_SHAKE_MAGNITUDE = 4 -- pixels
local SLAM_SHAKE_FRAMES = 8

local DEBUG = false

-- cranking logic
-- pd.getCrankChange() returns the change since it was LAST CALLED, so reading it more than
-- once per frame starves later readers. Sample once per frame and share the value.
local crankChangeThisFrame = 0
local crankFastGrace = 0

-- Crank speed is jittery frame to frame, so a single slow frame shouldn't drop a flutter.
local CRANK_FAST_GRACE_FRAMES = 2

local function sampleCrank()
   crankChangeThisFrame = pd.getCrankChange()
   if crankChangeThisFrame > CRANK_SPEED_THRESHOLD then
      crankFastGrace = CRANK_FAST_GRACE_FRAMES
   elseif crankChangeThisFrame < 0 then
      crankFastGrace = 0
   elseif crankFastGrace > 0 then
      crankFastGrace -= 1
   end
end

function IsCrankingFast()
   return crankFastGrace > 0
end

-- have a higher threshold for when the player is currently fluttering
function IsCrankingBackFast(threshold)
   return crankChangeThisFrame < -threshold
end

function Player:init(x, y, gameManager)
    self.gameManager = gameManager
    self.inventory = Inventory()

    -- state machine
    local playerImageTable = gfx.imagetable.new("images/player-table-32-32")
    Player.super.init(self, playerImageTable)

    self:addState("idle", 4, 7, {tickStep = 4})
    self:addState("run", 8, 13, {tickStep = 4})
    self:addState("jump", 14, 14, {tickStep = 1})
    self:addState("fall", 15, 15, {tickStep = 1})
    self:addState("flutter", 14, 15, {tickStep = 4})
    self:playAnimation()

    -- sprite stuff
    self:moveTo(x, y)
    self:setZIndex(Z_INDEXES.Player)
    self:setTag(TAGS.Player)
    self:setCollideRect(5, 5, 12, 20)
    self.collision = PlayerCollision(self)
    self.flutter = PlayerFlutter(self)
    self.slam = PlayerSlam(self, self.flutter)
    self.movement = PlayerMovement(self)
   
    -- physics properties
    self.x = x
    self.y = y
    self.xVelocity = 0
    self.yVelocity = 0

    -- jump physics
    self.jumpVelocity = JUMP_VELOCITY
    self.drag = 0.1
    self.minimumAirSpeed = 0.5
    self.jumpBufferTimer = 0

    -- player state
    self.touchingGround = false
    self.touchingCeiling = false
    self.touchingWall = false
    self.grounded = false
    self.dead = false
    self.airState = "fall"

    -- apex glide stuff
    self.apexGliding = false
    self.apexGliderTimer = 0
    self.apexPending = false

    -- coyote time
    self.coyoteTimer = 0

    -- Abilities
    self.doubleJumpAbility = false
    
    -- Double Jump
    self.doubleJumpAvailable = true
    

end

function Player:collisionResponse(other)
    return self.collision:getResponse(other)
end

function Player:update()
    sampleCrank()

    if self.dead then
        return
    end

    local wasGrounded = self.grounded
    local prevVy = self.yVelocity

    self:updateAnimation()

    self:handleState()
    self.slam:updateSlam(self, self.flutter)
    self.collision:moveAndCollide()
    if not self.slam.slamPhase then
        self.flutter:updateFlutterState(prevVy, self)
    end
    self:onLanding(wasGrounded)
    self.flutter:updateFlutterFuel()
    self:handlePlayerFall()
    self:handleCoyoteTime()
    self:checkForConsumeJump()
    self:updateFlutterAnimation()
end

-- "flutter" is a visual-only state layered over the jump/fall physics state.
function Player:updateFlutterAnimation()
    local state = self.currentState
    if self.flutter.fluttering and (state == "jump" or state == "fall") then
        self.airState = state
        self:changeState("flutter")
    elseif state == "flutter" and not self.flutter.fluttering then
        self:changeState(self.yVelocity < 0 and "jump" or "fall")
    end
end

function Player:handleState()
    local state = self.currentState
    if state == "flutter" then
        state = self.airState
    end

    if state == "idle" or state == "run" then
        self:applyGravity()
        self.movement:handleGroundInput(self)
        if (not self.touchingGround) and self.coyoteTimer <= 0 then
            self:changeToFallState()
        end
    elseif state == "jump" then
    if self.touchingGround then
        self:changeToIdleState()
    elseif self.yVelocity >= 0 then
        self:changeToFallState()
    end

    if not pd.buttonIsPressed(pd.kButtonUp) and self.yVelocity < JUMP_CUT_VELOCITY then
        self.yVelocity = JUMP_CUT_VELOCITY
    end
    self.movement:handleAirInput(self)
    elseif state == "fall" then
        if self.touchingGround then
            self:changeToIdleState()
        end
        self.movement:handleAirInput(self)
        self:handleAirJumpInput()
    end
end

function Player:handleAirJumpInput()
    if pd.buttonJustPressed(pd.kButtonUp) and self.doubleJumpAvailable and self.doubleJumpAbility then
        self.doubleJumpAvailable = false
        self.coyoteTimer = 0
        self:changeToJumpState()
    end
end

function Player:handleCoyoteTime()
    if self.grounded then
      self.coyoteTimer = COYOTE_FRAMES
  elseif self.coyoteTimer > 0 then
      self.coyoteTimer -= 1
  end
end

function Player:changeToJumpState()
    self.yVelocity = self.jumpVelocity
    self.flutter:resetForJump()
    self.apexGliding = false
    self.apexGliderTimer = 0
    self.apexPending = false
    self:changeState("jump")
end

function Player:changeToFallState()
    self:changeState("fall")
end

function Player:changeStateToRun()
    self:changeState("run")
end


function Player:checkForConsumeJump()
    if self.jumpBufferTimer > 0 and (self.grounded or self.coyoteTimer > 0) then
        self.yVelocity = JUMP_VELOCITY
        self.grounded = false
        self.jumpBufferTimer = 0
        self.coyoteTimer = 0
        self.flutter:handleLanding()
        self.apexGliding = false
        self.apexGliderTimer = 0
        self.apexPending = false
        self:changeState("jump")
    end
end

function Player:die()
    self.slam.slamPhase = nil
    self.xVelocity = 0
    self.yVelocity = 0
    self.slam.powered = false
    self.dead = true
    self:setCollisionsEnabled(false)
    pd.timer.performAfterDelay(200, function()
        self:setCollisionsEnabled(true)
        self.dead = false
        self.gameManager:resetPlayer()
    end)
end

function Player:changeToIdleState()
    self.xVelocity = 0
    self.flutter:refillFlutterFuel()
    self:changeState("idle")
end

-- physics helper functions
function Player:currentGravity()
    return self.yVelocity < 0 and RISE_GRAVITY or FALL_GRAVITY
end

function Player:applyGravity()
    self.yVelocity += self:currentGravity()
end

function Player:addGravityForce()
    self.yVelocity += self:currentGravity()
end

function Player:applyDrag(amount)
    if math.abs(self.xVelocity) <= amount or self.touchingWall then
        self.xVelocity = 0
        return
    end
    self.xVelocity -= amount * (self.xVelocity > 0 and 1 or -1)
end

function Player:resetApexGlideTimer()
    self.apexGliderTimer = APEX_GLIDE_HOLD_FRAMES
end

-- Player fall logic
function Player:handlePlayerFall()
    if self.slam.slamPhase then
        return
    end
    if self.yVelocity > MAX_FALL_SPEED then
        self.yVelocity = MAX_FALL_SPEED
    end
end

-- Coyote time
function Player:checkForCoyoteTime()
    if self.grounded then
        self.coyoteTimer = COYOTE_FRAMES
    elseif self.coyoteTimer > 0 then
        self.coyoteTimer -= 1
    end
end

function Player:onLanding(wasGrounded)
    if self.grounded then
        if self.slam:isPowerSlamming() and self.gameManager then
            self.gameManager.camera:shake(SLAM_SHAKE_MAGNITUDE, SLAM_SHAKE_FRAMES)
        end
        self.slam.slamPhase = nil
        self.slam.powered = false
        self.slam.slamPhase = nil
        self.flutter:handleLanding(wasGrounded)
        self.apexGliding = false
        self.apexGliderTimer = 0
    end
end
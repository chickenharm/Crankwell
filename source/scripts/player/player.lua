import "scripts/player/playerFlutter"

local pd <const> = playdate
local gfx <const> = playdate.graphics

--- @class Player : AnimatedSprite
Player = {}
class('Player').extends(AnimatedSprite)

-- Constants
local CRANK_SPEED_THRESHOLD = 3



-- Apex glide properties
local APEX_GLIDE_HOLD_FRAMES = 4

-- Fall properties
local MAX_FALL_SPEED = 12
local GRAVITY = 0.8
local FALL_DEATH_MARGIN = 32 -- extra pixels below the level bottom before death triggers

-- Coyote properties
local COYOTE_FRAMES = 6

-- jump properties
local JUMP_VELOCITY = -9.5


-- slam properties
local SLAM_CRANK_THRESHOLD = 12 -- degrees per frame, backwards
local SLAM_CRANK_THRESHOLD_WHILE_IN_OTHER_STATE = 20;
local SLAM_FREEZE_FRAMES = 12
local SLAM_SPEED = 16
local SLAM_SHAKE_MAGNITUDE = 4 -- pixels
local SLAM_SHAKE_FRAMES = 8


local DEBUG = false

-- cranking logic
function IsCrankingFast()
   return pd.getCrankChange() > CRANK_SPEED_THRESHOLD
end

-- have a higher threshold for when the player is currently fluttering
local function isCrankingBackFast(threshold)
   local change = pd.getCrankChange()
   return change < -threshold
end

function Player:init(x, y, gameManager)
    self.gameManager = gameManager

    -- state machine
    local playerImageTable = gfx.imagetable.new("images/player-table-32-32")
    Player.super.init(self, playerImageTable)

    self:addState("idle", 4, 7, {tickStep = 4})
    self:addState("run", 8, 13, {tickStep = 4})
    self:addState("jump", 14, 15, {tickStep = 4})
    self:addState("fall", 14, 15, {tickStep = 4})
    self:playAnimation()

    -- sprite stuff
    self:moveTo(x, y)
    self:setZIndex(Z_INDEXES.Player)
    self:setTag(TAGS.Player)
    self:setCollideRect(5, 5, 12, 20)
    self.collision = PlayerCollision(self)
    self.flutter = PlayerFlutter(self)
   
    -- physics properties
    self.x = x
    self.y = y
    self.xVelocity = 0
    self.yVelocity = 0
    self.gravity = GRAVITY
    self.maxSpeed = 2.0

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
    

    -- apex glide stuff
    self.apexGliding = false
    self.apexGliderTimer = 0
    self.apexPending = false
    -- slam state: nil, "freeze" or "drop"
    self.slamPhase = nil
    self.slamFreezeTimer = 0

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
    if self.dead then
        return
    end

    local wasGrounded = self.grounded
    local prevVy = self.yVelocity

    self:updateAnimation()

    self:handleState()
    self:updateSlam()
    self.collision:moveAndCollide()
    if not self.slamPhase then
        self.flutter:updateFlutterState(prevVy, self)
    end
    self:onLanding(wasGrounded)
    self.flutter:updateFlutterFuel()
    self:handlePlayerFall()
    self:handleCoyoteTime()
    self:checkForConsumeJump()
    self:checkForFallDeath()
end

-- Runs after handleState so it overrides any input/drag/gravity velocity changes.
function Player:updateSlam()
    if not self.slamPhase then
        -- self.fluttering still holds last frame's value here (updateFlutterState runs later)
        local threshold = self.flutter.fluttering and SLAM_CRANK_THRESHOLD_WHILE_IN_OTHER_STATE or SLAM_CRANK_THRESHOLD
        if (not self.grounded) and (not self.touchingGround) and isCrankingBackFast(threshold) then
            self.slamPhase = "freeze"
            self.slamFreezeTimer = SLAM_FREEZE_FRAMES
            self.flutter:cancelFlutterAndGlide()
        else
            return
        end
    end

    if self.slamPhase == "freeze" then
        self.xVelocity = 0
        self.yVelocity = 0
        self.slamFreezeTimer -= 1
        if self.slamFreezeTimer <= 0 then
            self.slamPhase = "drop"
        end
    else
        self.xVelocity = 0
        self.yVelocity = SLAM_SPEED
    end
end

function Player:handleState()
    if self.currentState == "idle" or self.currentState == "run" then
        self:applyGravity()
        self:handleGroundInput()
        if (not self.touchingGround) and self.coyoteTimer <= 0 then
            self:changeToFallState()
        end
    elseif self.currentState == "jump" then
        if self.touchingGround then
            self:changeToIdleState()
        elseif self.yVelocity >= 0 then
            self:changeToFallState()
        end
        self:applyDrag(self.drag)
        self:handleAirInput()
    elseif self.currentState == "fall" then
        if self.touchingGround then
            self:changeToIdleState()
        end
        self:applyDrag(self.drag)
        self:handleAirInput()
        self:handleAirJumpInput() -- checks coyoteTimer/jumpBufferTimer
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
    self.slamPhase = nil
    self.xVelocity = 0
    self.yVelocity = 0
    self.dead = true
    self:setCollisionsEnabled(false)
    pd.timer.performAfterDelay(200, function()
        self:setCollisionsEnabled(true)
        self.dead = false
        self.gameManager:resetPlayer()
    end)
end

-- input helper functions
function Player:handleGroundInput()
    if pd.buttonJustPressed(pd.kButtonUp) then
        self:changeToJumpState()
    elseif self.jumpBufferTimer > 0 then
        self.jumpBufferTimer -= 1
    elseif pd.buttonIsPressed(pd.kButtonLeft) then
        self:changeToRunState("left")
    elseif pd.buttonIsPressed(pd.kButtonRight) then
        self:changeToRunState("right")
    else
        self:changeToIdleState()
    end
end

function Player:handleAirInput()
    if pd.buttonIsPressed(pd.kButtonLeft) then
        self.xVelocity = -self.maxSpeed
        if not self.grounded then
            self.globalFlip = 1
        end
    elseif pd.buttonIsPressed(pd.kButtonRight) then
        self.xVelocity = self.maxSpeed
         if not self.grounded then
            self.globalFlip = 0
        end
    end
end

function Player:changeToIdleState()
    self.xVelocity = 0
    self.flutter:refillFlutterFuel()
    self:changeState("idle")
end

function Player:changeToRunState(direction)
    if direction == "left" then
        self.xVelocity = -self.maxSpeed
        self.globalFlip = 1
    elseif direction == "right" then
        self.xVelocity = self.maxSpeed
        self.globalFlip = 0
    end
    self:changeState("run")
end

-- physics helper functions
function Player:applyGravity()
    self.yVelocity += self.gravity
end

function Player:applyDrag(amount)
    if self.xVelocity > 0 then
        self.xVelocity -= amount
    elseif self.xVelocity < 0 then
        self.xVelocity += amount
    end

    if math.abs(self.xVelocity) < self.minimumAirSpeed or self.touchingWall then
        self.xVelocity = 0
    end
end


function Player:resetApexGlideTimer()
    self.apexGliderTimer = APEX_GLIDE_HOLD_FRAMES
end

function Player:addGravityForce()
    self.yVelocity += GRAVITY
end

function Player:onLanding(wasGrounded)
    if self.grounded then
        if self.slamPhase == "drop" and self.gameManager then
            self.gameManager:shakeCamera(SLAM_SHAKE_MAGNITUDE, SLAM_SHAKE_FRAMES)
        end
        self.slamPhase = nil
        self.flutter:handleLanding(wasGrounded)
        self.apexGliding = false
        self.apexGliderTimer = 0
    end
end

-- Player fall logic
function Player:handlePlayerFall()
    if self.slamPhase then
        return
    end
    if self.yVelocity > MAX_FALL_SPEED then
        self.yVelocity = MAX_FALL_SPEED
    end
end

function Player:checkForFallDeath()
    local levelRect = self.gameManager and self.gameManager.levelRect
    if levelRect and self.y > levelRect.y + levelRect.height + FALL_DEATH_MARGIN then
        self:die()
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
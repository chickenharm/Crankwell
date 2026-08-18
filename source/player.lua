local pd <const> = playdate
local gfx <const> = playdate.graphics

--- @class Player : AnimatedSprite
Player = {}
class('Player').extends(AnimatedSprite)

-- Constants
local CRANK_SPEED_THRESHOLD = 6

-- Flutter properties
local FLUTTER_FUEL_MAX = 40
local FLUTTER_FUEL_REGEN_ON_LAND = true
local FLUTTER_APEX_HOLD_FRAMES = 3
local FLUTTER_LIFT_PIXELS = 32
local FLUTTER_LIFT_SPEED = -1.0
local FLUTTER_DROP_PIXELS = 16
local FLUTTER_DROP_SPEED = 2.4

-- Fall properties
local MAX_FALL_SPEED = 12

-- Coyote properties
local COYOTE_FRAMES = 6

-- jump properties
local JUMP_VELOCITY = -10



-- cranking logic
local function isCrankingFast()
   local change = pd.getCrankChange()
   return math.abs(change) > CRANK_SPEED_THRESHOLD
end

function Player:init(x, y)

    -- state machine
    local playerImageTable = gfx.imagetable.new("images/player-table-32-32")
    Player.super.init(self, playerImageTable)

    self:addState("idle", 4, 7, {tickStep = 4})
    self:addState("run", 8, 13, {tickStep = 4})
    self:addState("jump", 14, 15, {tickStep = 4})
    self:playAnimation()

    -- sprite stuff
    self:moveTo(x, y)
    self:setZIndex(Z_INDEXES.Player)
    self:setTag(TAGS.Player)
    self:setCollideRect(5, 5, 12, 20)
   
    -- physics properties
    self.x = x
    self.y = y
    self.xVelocity = 0
    self.yVelocity = 0
    self.gravity = 0.8
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
    
    -- flutter state
    self.fluttering = false
    self.flutterFuel = FLUTTER_FUEL_MAX
    self.flutterApexHoldTimer = 0
    self.flutterLiftRemaining = 0
    self.flutterDropRemaining = 0
    self.flutterSequenceDone = false

    -- apex glide stuff
    self.apexGliding = false
    self.apexGliderTimer = 0

    -- coyote time
    self.coyoteTimer = 0

end

function Player:collisionResponse()
    return gfx.sprite.kCollisionTypeSlide
end

function Player:update()
    local wasGrounded = self.grounded
    local prevVy = self.yVelocity

    self:updateAnimation()

    self:handleState()
    self:handleMovementAndCollisions()
    self:updateFlutterState(prevVy)
    self:onLanding(wasGrounded)
    self:updateFlutterFuel()
    self:handlePlayerFall()
    self:checkForCoyoteTime()
    self:checkForConsumeJump()
end

function Player:handleState()
    if self.currentState == "idle" then
        self:applyGravity()
        self:handleGroundInput()
    elseif self.currentState == "run" then
        self:applyGravity()
        self:handleGroundInput()
    elseif self.currentState == "jump" then
        if self.touchingGround then
            self:changeToIdleState()
        end
        self:applyGravity()
        self:applyDrag(self.drag)
        self:handleAirInput()
    end
end

function Player:changeToJumpState()
    self.yVelocity = self.jumpVelocity
    self.flutterSequenceDone = false
    self.flutterDropRemaining = 0
    self:changeState("jump")
end

function Player:checkForConsumeJump()
    if self.jumpBufferTimer > 0 and (self.grounded or self.coyoteTimer > 0) then
        self.yVelocity = JUMP_VELOCITY
        self.grounded = false
        self.jumpBufferTimer = 0
        self.coyoteTimer = 0
        self.fluttering = false
        self.flutterApexHoldTimer = 0
        self.flutterLiftRemaining = 0
        self.flutterSequenceDone = false
    end
end

function Player:handleMovementAndCollisions()
    local _, _, collisions, length = self:moveWithCollisions(self.x + self.xVelocity, self.y + self.yVelocity)
    
    self.touchingGround = false
    self.touchingCeiling = false
    self.touchingWall = false

    for i = 1, length do
        local collision = collisions[i]
        if collision.normal.y == -1 then
            self.touchingGround = true
        elseif collision.normal.y == 1 then
            self.touchingCeiling = true
        end

          if collision.normal.x ~= 0 then
            self.touchingWall = true
        end
    end

    self.grounded = self.touchingGround
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
    elseif pd.buttonIsPressed(pd.kButtonRight) then
        self.xVelocity = self.maxSpeed
    end
end

function Player:changeToIdleState()
    self.xVelocity = 0
    self.flutterFuel = FLUTTER_FUEL_MAX
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
    if self.touchingGround or self.touchingCeiling then
        self.yVelocity = 0
    end
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


-- flutter logic
function Player:updateFlutterState(prevVy)
    self.fluttering = (not self.grounded) and self.flutterFuel > 0 and isCrankingFast()

    if not self.fluttering then
        self.flutterDropRemaining = 0
        self.flutterApexHoldTimer = 0
        self.flutterLiftRemaining = 0
    end

    local atApexTransition = prevVy < 0 and (prevVy + self.gravity) >= 0

    if self.fluttering and (not self.flutterSequenceDone) and atApexTransition then
        self.flutterDropRemaining = FLUTTER_DROP_PIXELS
        self.flutterApexHoldTimer = 0
        self.flutterLiftRemaining = FLUTTER_LIFT_PIXELS
    end

    -- Phase 1: short drop
    if self.flutterDropRemaining > 0 and self.fluttering then
        self.yVelocity = FLUTTER_DROP_SPEED
        self.flutterDropRemaining -= FLUTTER_DROP_SPEED
        self.flutterFuel -= 1

        if self.flutterDropRemaining <= 0 then
            self.flutterDropRemaining = 0
            self.flutterApexHoldTimer = FLUTTER_APEX_HOLD_FRAMES
        end

    -- Phase 2 hold position
    elseif self.flutterApexHoldTimer > 0 then
        self.yVelocity = 0
        self.flutterApexHoldTimer -= 1

    -- Phase 3: move up
    elseif self.flutterLiftRemaining > 0 and self.fluttering then
        self.yVelocity = FLUTTER_LIFT_SPEED
        self.flutterLiftRemaining -= math.abs(FLUTTER_LIFT_SPEED)
        self.flutterFuel -= 1

        if self.flutterLiftRemaining <= 0 then
            self.flutterLiftRemaining = 0
            self.flutterSequenceDone = true
        end

    elseif (not self.grounded) or self.yVelocity < 0 then
        self.yVelocity += self.gravity
    else
        self.yVelocity = 0
    end
end

function Player:onLanding(wasGrounded)
    if self.grounded then
        if (not wasGrounded) and FLUTTER_FUEL_REGEN_ON_LAND then
            self.flutterFuel = FLUTTER_FUEL_MAX
        end
        self.fluttering = false
        self.flutterApexHoldTimer = 0
        self.flutterLiftRemaining = 0
        self.flutterDropRemaining = 0
        -- add apex glide stuff here
        self.apexGliding = false
        self.apexGliderTimer = 0
    end
end

function Player:updateFlutterFuel()
    if self.flutterFuel < 0 then
        self.flutterFuel = 0
    end
end

-- Player fall logic
function Player:handlePlayerFall()
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
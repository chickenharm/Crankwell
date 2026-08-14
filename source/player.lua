local pd <const> = playdate
local gfx <const> = playdate.graphics

--- @class Player : AnimatedSprite
Player = {}
class('Player').extends(AnimatedSprite)

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
   
    -- physics
    self.x = x
    self.y = y
    self.xVelocity = 0
    self.yVelocity = 0
    self.gravity = 1.0
    self.maxSpeed = 2.0

    -- jump physics
    self.jumpVelocity = -6

    -- player state
    self.touchingGround = false
end

function Player:collisionResponse()
    return gfx.sprite.kCollisionTypeSlide
end

function Player:update()
    self:updateAnimation()

    self:handleState()
    self:handleMovementAndCollisions()
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
        self:handleAirInput()
    end
end

function Player:handleAirInput()
    if pd.buttonIsPressed(pd.kButtonLeft) then
        self.xVelocity = -self.maxSpeed
    elseif pd.buttonIsPressed(pd.kButtonRight) then
        self.xVelocity = self.maxSpeed
    end
end

function Player:changeToJumpState()
    self.yVelocity = self.jumpVelocity
    self:changeState("jump")
end


function Player:handleMovementAndCollisions()
    local _, _, collisions, length = self:moveWithCollisions(self.x + self.xVelocity, self.y + self.yVelocity)
    self.touchingGround = false

    for i = 1, length do
        local collision = collisions[i]
        if collision.normal.y == -1 then
            self.touchingGround = true
        end
    end
end

-- input helper functions
function Player:handleGroundInput()
    if pd.buttonJustPressed(pd.kButtonA) then
        self:changeToJumpState()
    elseif pd.buttonIsPressed(pd.kButtonLeft) then
        self:changeToRunState("left")
    elseif pd.buttonIsPressed(pd.kButtonRight) then
        self:changeToRunState("right")
    else
        self:changeToIdleState()
    end
end

function Player:changeToIdleState()
    self.xVelocity = 0
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
    if self.touchingGround then
        self.yVelocity = 0
    end
end





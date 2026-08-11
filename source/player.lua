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
    self:addState("jump", 14, 15)
    self:playAnimation()

    -- sprite stuff
    self:moveTo(x, y)
    self:setZIndex(Z_INDEXES.Player)
    self:setTag(TAGS.Player)
    self:setCollideRect(3, 3, 10, 13)

    --physics
    self.x = x
    self.y = y
    self.xVelocity = 0
    self.yVelocity = 0
    self.gravity = 1.0
    self.maxSpeed = 2.0

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
    end
end

function Player:handleMovementAndCollisions()
    local _, _, collisions, length = self:moveWithCollisions(self.x + self.xVelocity, self.y + self.yVelocity)

    for i = 1, length do
        local collision = collisions[i]
        if collision.normal.y == -1 then
            self.touchingGround = true
        end
    end
end

-- input helper functions
function Player:handleGroundInput()
    if pd.buttonIsPressed(pd.kButtonLeft) then
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
    elseif direction == "right" then
        self.xVelocity = self.maxSpeed
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





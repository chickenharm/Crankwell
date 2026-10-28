local gfx <const> = playdate.graphics
local enemyImage <const> = gfx.image.new("images/enemies/enemy")


--- @class Enemy : AnimatedSprite
Enemy = {}
class("Enemy").extends(AnimatedSprite)

Enemy.DEFAULT_SHEET = "images/enemies/enemy-table-16-16"
Enemy.STUN_FRAMES = 45  -- ~1.5s at Playdate's default 30 fps


function Enemy:init(x, y, entity, sheetPath)
    self:setZIndex(Z_INDEXES.Enemy)
    local imageTable = gfx.imagetable.new(sheetPath or Enemy.DEFAULT_SHEET)
    Enemy.super.init(self, imageTable)

    self:setupAnimations()
    self:playAnimation()

    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:add()
    -- Collision Config
    self:setTag(TAGS.Enemy)
    self:setCollideRect(0, 0, 16, 16)

    self.isDead = false;
    self.canHurtPlayer = true
    self.stunFrames = 0

    self.x = x
    self.y = y
    local fields = entity.fields
    self.jumpProtected = false; -- check this true if this enemy can only be hurt by slam

    self.xVelocity = fields.xVelocity or 1
    self.yVelocity = fields.yVelocity or 0
    self.affectedByGravity = self.yVelocity == 0
    self.fallSpeed = 0

    self.maxDistance = fields.maxDistance
    self:resetDistanceTraveled()
    self.isLedgeEnemy = fields.isLedgeEnemy
    self.recovering = false

    self.patrolAxis = patrolAxis or "x"   -- "x", "y", or "both"

end

function Enemy:damageEnemy()
    self.xVelocity = 0
    self.yVelocity = 0
    self.dead = true
    self:setCollisionsEnabled(false)
    self:destroy()
end

function Enemy:destroy()
    self:remove()
end

function Enemy:collisionResponse(other)
    if other:getTag() == TAGS.Player then
        return gfx.sprite.kCollisionTypeOverlap
    end
    return gfx.sprite.kCollisionTypeSlide
end

function Enemy:update()
    self:updateStun()
    self:updateAnimation()
    local prevX, prevY = self:getPosition()

    if self.affectedByGravity then
        self.fallSpeed = math.min(self.fallSpeed + 0.5, 6)
        self.yVelocity = self.fallSpeed
    end

    local _, _, collisions, length = self:moveWithCollisions(prevX + self.xVelocity, prevY + self.yVelocity)
    local hitWall = false
    self.onGround = false -- reset each frame

    for i = 1, length do
        local collision = collisions[i]
        if collision.other:getTag() ~= TAGS.Player then
            if collision.normal.y ~= 0 and self.affectedByGravity then
                self.fallSpeed = 0
                self.yVelocity = 0
                if collision.normal.y == -1 then self.onGround = true end
            elseif collision.normal.x ~= 0 or not self.affectedByGravity then
                hitWall = true
            end
        end
    end

    if hitWall then
        self.xVelocity *= -1
        if not self.affectedByGravity then self.yVelocity *= -1 end
        self:resetDistanceTraveled()
        return
    end
end

function Enemy:setupAnimations()
      self:addState("idle", 1, 4, {tickStep = 4})
end

function Enemy:resetDistanceTraveled()
    self.distanceTraveled = 0
end

-- Called by the player when landing on this enemy with a normal jump.
-- Returns true if the player should bounce.
function Enemy:onStomped()
    if self.jumpProtected then
        self:stun()
    else
        self:damageEnemy()
    end
    return true
end

-- Called by the player when power slamming onto this enemy.
-- Returns true if the player should bounce.
function Enemy:onSlammed()
    if self.jumpProtected then
        self:removeJumpProtection()
        self:stun()
    else
        self:damageEnemy()
    end
    return true
end

function Enemy:removeJumpProtection()
    self.jumpProtected = false
end

function Enemy:isStunned()
    return self.stunFrames > 0
end

function Enemy:stun(frames)
    if not self:isStunned() and not self.recovering then
        self.savedXVelocity = self.xVelocity
        self.xVelocity = 0
    end
    self.canHurtPlayer = false
    self.stunFrames = frames or self.STUN_FRAMES
end

function Enemy:updateStun()
    if self.stunFrames > 0 then
        self.stunFrames -= 1
        if self.stunFrames == 0 then
            self:recoverFromStun()
        end
    end
end

function Enemy:recoverFromStun()
    self.stunFrames = 0
    self.xVelocity = self.savedXVelocity or self.xVelocity
    self:changeState("idle")
    self.canHurtPlayer = true
end
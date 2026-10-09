local gfx <const> = playdate.graphics
local enemyImage <const> = gfx.image.new("images/enemies/enemy")


--- @class Enemy : AnimatedSprite
Enemy = {}
class("Enemy").extends(AnimatedSprite)


function Enemy:init(x, y, entity)
    self:setZIndex(Z_INDEXES.Enemy)
    local enemyImageTable = gfx.imagetable.new("images/enemies/enemy-table-16-16")
    Enemy.super.init(self, enemyImageTable)

    self:addState("idle", 1, 4, {tickStep = 4})
    self:playAnimation()

    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:add()
    -- Collision Config
    self:setTag(TAGS.Enemy)
    self:setCollideRect(0, 0, 16, 16)

    self.isCrushable = true; -- check this true if this enemy can be hurt by player dropping on top of it
    self.isDead = false;

    self.x = x
    self.y = y
    local fields = entity.fields
    self.xVelocity = fields.xVelocity or 1
    self.yVelocity = fields.yVelocity or 0
    self.affectedByGravity = self.yVelocity == 0
    self.fallSpeed = 0

    self.maxDistance = fields.maxDistance
    self.distanceTraveled = 0

end

function Enemy:die()
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
    self:updateAnimation()
    local prevX, prevY = self:getPosition()
    local prevXVel, prevYVel = self.xVelocity, self.yVelocity

    -- ground walkers (no vertical velocity set) fall until they land on a solid tile
    if self.affectedByGravity then
        self.fallSpeed = math.min(self.fallSpeed + 0.5, 6)
        self.yVelocity = self.fallSpeed
    end

    local _, _, collisions, length = self:moveWithCollisions(prevX + self.xVelocity, prevY + self.yVelocity)
    local hitWall = false
    for i = 1, length do
        local collision = collisions[i]
        if collision.other:getTag() ~= TAGS.Player then
            if collision.normal.y ~= 0 and self.affectedByGravity then
                self.fallSpeed = 0
                self.yVelocity = 0
            elseif collision.normal.x ~= 0 or not self.affectedByGravity then
                hitWall = true
            end
        end
    end

    if hitWall then
        self.xVelocity *= -1
        if not self.affectedByGravity then self.yVelocity *= -1 end
        self.distanceTraveled = 0
        return
    end

    local x, y = self:getPosition()
    local dx, dy = x - prevX, y - prevY
    self.distanceTraveled += math.sqrt(dx * dx + dy * dy)

    if self.maxDistance and self.maxDistance > 0 and self.distanceTraveled >= self.maxDistance then
        self.xVelocity *= -1
        if not self.affectedByGravity then self.yVelocity *= -1 end
        self.distanceTraveled = 0
    end
end

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
    self:setCollideRect(4, 4, 16, 16)

    self.isCrushable = true; -- check this true if this enemy can be hurt by player dropping on top of it
    self.isDead = false;

    self.x = x
    self.y = y
    local fields = entity.fields
    self.xVelocity = fields.xVelocity
    self.yVelocity = fields.yVelocity or 0

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



function Enemy:update()
    self:updateAnimation()
    local prevX, prevY = self.x, self.y
    local prevXVel, prevYVel = self.xVelocity, self.yVelocity

    local _, _, collisions, length = self:moveWithCollisions(self.x + self.xVelocity, self.y + self.yVelocity)
    local hitWall = false
    for i = 1, length do
        local collision = collisions[i]
        if collision.other:getTag() ~= TAGS.Player then
            hitWall = true
        end
    end

    if hitWall then
        self.xVelocity *= -1
    end

    -- the parent flipped velocity, so a wall was hit: restart the count
    if self.xVelocity ~= prevXVel or self.yVelocity ~= prevYVel then
        self.distanceTraveled = 0
        return
    end

    local dx, dy = self.x - prevX, self.y - prevY
    self.distanceTraveled += math.sqrt(dx * dx + dy * dy)

    if self.maxDistance and self.maxDistance > 0 and self.distanceTraveled >= self.maxDistance then
        self.xVelocity *= -1
        self.yVelocity *= -1
        self.distanceTraveled = 0
    end


end
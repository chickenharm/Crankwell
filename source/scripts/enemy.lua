local gfx <const> = playdate.graphics
local enemyImage <const> = gfx.image.new("images/enemies/enemy")


--- @class Enemy : AnimatedSprite
Enemy = {}
class("Enemy").extends(AnimatedSprite)


function Enemy:init(x, y, entity)
    self:setZIndex(Z_INDEXES.Enemy)
    local enemyImageTable = gfx.imagetable.new("images/enemies/enemy-table-16-16")
    Enemy.super.init(self, enemyImageTable)

    self:addState("idle", 4, 7, {tickStep = 4})


    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:add()
    -- Collision Config
    self:setTag(TAGS.Enemy)
    self:setCollideRect(4, 4, 16, 16)

    self.x = x
    self.y = y
    local fields = entity.fields
    self.xVelocity = fields.xVelocity
    self.yVelocity = fields.yVelocity or 0

end

function Enemy:destroy()
    self:remove()
end



function Enemy:update()
    self:updateAnimation()

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


end
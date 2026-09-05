local gfx <const> = playdate.graphics
local spikeBallImage <const> = gfx.image.new("images/spikeball")

Spikeball = {}
class('Spikeball').extends(gfx.sprite)


function Spikeball:init(x, y, entity)
    self:setZIndex(Z_INDEXES.Hazzard)
    self:setImage(spikeBallImage)
    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:add()

    self:setTag(TAGS.Hazzard)
    self:setCollideRect(4, 4, 8, 8)

    local fields = entity.fields
    self.xVelocity = fields.xVelocity
    self.yVelocity = fields.yVelocity
end

function Spikeball:collisionResponse()
    return gfx.sprite.kCollisionTypeBounce
end
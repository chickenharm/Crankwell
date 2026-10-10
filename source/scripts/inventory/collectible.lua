local gfx <const> = playdate.graphics

--- @class Collectible : playdate.graphics.sprite
Collectible = {}
class('Collectible').extends(gfx.sprite)

function Collectible:init(x, y, entity, imagePath)
    Collectible.super.init(self)
    self.fields = entity.fields
    if self.fields.pickedUp then
        return
    end

    local image = gfx.image.new(imagePath)
    assert(image, "missing image: " .. imagePath)
    self:setImage(image)
    self:setZIndex(Z_INDEXES.Pickup)
    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:add()

    self:setTag(TAGS.Pickup)
    self:setCollideRect(0, 0, self:getSize())
end

-- Shared flow: subclasses don't override this
function Collectible:pickUp(player)
    self:onPickUp(player)
    self.fields.pickedUp = true
    self:remove()
end

-- Override in subclasses
function Collectible:onPickUp(player) end
local gfx <const> = playdate.graphics


--- @class Door : playdate.graphics.sprite
Door = {}
class('Door').extends(gfx.sprite)

function Door:init(x, y, entity, image)
    Door.super.init(self)
    self.fields = entity.fields
    if self.fields.unlocked then
        return
    end

    assert(image, "missing image for door")

    self:setImage(image)
    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:setZIndex(Z_INDEXES.Hazzard)
    self:setCollideRect(0, 0, self:getSize())
    self:add()
end
local gfx <const> = playdate.graphics


--- @class Door : playdate.graphics.sprite
Door = {}
class('Door').extends(gfx.sprite)

function Door:init(x, y, entity)
    Door.super.init(self)
    self.fields = entity.fields
    if self.fields.unlocked then
        return
    end

    local image = LDtk.generate_image_from_entity(entity)
    assert(image, "door entity has no tile image")

    self:setImage(image)
    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:setCollideRect(0, 0, self:getSize())
    self:add()
end


function Door:open()
    self.fields.unlocked = true
    self:remove()
end


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
    self.keyId = self.fields.keyId

    self:setImage(image)
    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:setCollideRect(0, 0, self:getSize())
    self:add()
end

function Door:tryUnlock(player, keyId)
   if player.inventory:consume("key" ..self.keyId) then
    self.fields.unlocked = true
    self:remove()
    return true
   end
   return false
end
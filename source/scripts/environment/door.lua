local gfx <const> = playdate.graphics


---@class Door : playdate.graphics.sprite
Door = {}
class('Door').extends(gfx.sprite)

function Door:init(x, y, entity)
    self.fields = entity.fiends

    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:setZIndex(Z_INDEXES.Pickup)
    self:setCollideRect(0, 0, self:getSize())
    self:add()
end
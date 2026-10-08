import "CoreLibs/object"
import "CoreLibs/sprites"

local gfx <const> = playdate.graphics


--- @class BreakableBlock : playdate.graphics.sprite
BreakableBlock = {}
class('BreakableBlock').extends(gfx.sprite)

function BreakableBlock:init(x, y, image)
    BreakableBlock.super.init(self)

    self:setImage(image)
    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:setCollideRect(0, 0, self:getSize())
    self:setTag(TAGS.Breakable)
    self:add()
end


function BreakableBlock:breakBlock()
    self:remove()
end
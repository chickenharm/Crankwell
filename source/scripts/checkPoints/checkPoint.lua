-- scripts/checkpoint.lua
local gfx <const> = playdate.graphics

class("Checkpoint").extends(gfx.sprite)

-- GameScene assigns this so the checkpoint doesn't need to know about the scene
Checkpoint.onActivated = nil

function Checkpoint:init(x, y, entity)
    Checkpoint.super.init(self)
    local w = (entity.size and entity.size.width) or 16
    local h = (entity.size and entity.size.height) or 16

    self.levelRespawnX = x + w / 2
    self.levelRespawnY = y + h / 2   -- adjust to match your player's origin
    self.active = false

    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:setSize(w, h)
    self:setCollideRect(0, 0, w, h)
    self:setTag(TAGS.Checkpoint)
    self:setZIndex(Z_INDEXES.Pickup)
    self:setImage(self:makeImage(w, h, false))
    self:add()
end

function Checkpoint:makeImage(w, h, active)
    local img = gfx.image.new(w, h)
    gfx.pushContext(img)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawLine(2, 0, 2, h)                  -- pole
        if active then
            gfx.fillTriangle(2, 0, 2, 7, w - 2, 3) -- flag
        else
            gfx.drawTriangle(2, 0, 2, 7, w - 2, 3)
        end
    gfx.popContext()
    return img
end

function Checkpoint:activate()
    self.active = true
    local w, h = self:getSize()
    self:setImage(self:makeImage(w, h, true))
end

function Checkpoint:update()
    for _, s in ipairs(self:overlappingSprites()) do
        if s:getTag() == TAGS.Player then
            if Checkpoint.onActivated then
                Checkpoint.onActivated(self)
            end
            return
        end
    end
end
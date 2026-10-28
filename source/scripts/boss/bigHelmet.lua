local gfx <const> = playdate.graphics

--- @class BigHelmet : Boss
BigHelmet = {}
class('BigHelmet').extends(Boss)

local SIZE <const> = 48

local SHEET <const> = "images/bosses/test/mm_wheelie/MM-Wheelie-table-48-32"

function BigHelmet:init(x, y, entity)
    BigHelmet.super.init(self, x, y, entity, SHEET)
    self:setCollideRect(0, 0, 48, 32)
    self.fsm:add("charge", ChargeState) -- attack states that only this boss has
end

function BigHelmet:update()
    BigHelmet.super.update(self)
    local prevX, prevY = self:getPosition()
    self:patrol(prevX, prevY)
end
-- Returns true if there is solid ground just ahead of the leading foot
function BigHelmet:isGroundAhead()
    local x, y = self:getPosition() -- top-left, since center is (0, 0)
    local probeX = (self.xVelocity > 0) and (x + SIZE + 1) or (x - 2)
    local probeY = y + SIZE + 2

    local sprites = gfx.sprite.querySpritesAtPoint(probeX, probeY)
    local found = false
    for i = 1, #sprites do
        local tag = sprites[i]:getTag()
        if tag ~= TAGS.Enemy and tag ~= TAGS.Player then
            found = true
            break
        end
    end
    return found
end

function BigHelmet:patrol(prevX, prevY)
    local x, y = self:getPosition()
    local dx, dy = x - prevX, y - prevY

    if self.patrolAxis == "x" then
        self.distanceTraveled += math.abs(dx)
    elseif self.patrolAxis == "y" then
        self.distanceTraveled += math.abs(dy)
    else
        self.distanceTraveled += math.sqrt(dx * dx + dy * dy)
    end

    if self.maxDistance and self.maxDistance > 0
       and self.distanceTraveled >= self.maxDistance then
        self.distanceTraveled -= self.maxDistance  -- keep overshoot

        if self.patrolAxis ~= "y" then
            self.xVelocity = -self.xVelocity
        end
        if self.patrolAxis ~= "x" then
            self.yVelocity = -self.yVelocity
        end
    end
end
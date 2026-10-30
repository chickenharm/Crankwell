local gfx <const> = playdate.graphics

--- @class BigHelmet : Boss
BigHelmet = {}
class('BigHelmet').extends(Boss)

local SIZE <const> = 48

local CHARGE_FRAMES = 20

local CHARGE_RANGE <const> = 160   -- how far ahead the boss can see
local VERTICAL_TOLERANCE <const> = 24  -- player must be roughly on the boss's level
local CHARGE_COOLDOWN_TIME =  90

local SHEET <const> = "images/bosses/test/mm_wheelie/MM-Wheelie-table-48-32"
local ChargeState = {}
BigHelmet.ART_FACING = 1

function BigHelmet:init(x, y, entity)
    BigHelmet.super.init(self, x, y, entity, SHEET)
    self:setCollideRect(0, 0, 48, 32)
    self.fsm:add("charge", ChargeState) -- attack states that only this boss has
    local fields = entity.fields
    self.chargeSpeed = fields.xVelocity * 1.5
    self.chargeCooldown = 0
end


function BigHelmet:afterMove(prevX, prevY)
    local x = self:getPosition()
    self.distanceTraveled += math.abs(x - prevX)

    local atLimit = self.maxDistance and self.distanceTraveled >= self.maxDistance
    local ledge = self.isLedgeEnemy and not self:isGroundAhead()

    if atLimit or ledge then
        self.xVelocity = -self.xVelocity
        self:resetDistanceTraveled()
    end

     if self:canCharge() then
           self.fsm:change("charge")
       end
   end

   function BigHelmet:canCharge()
       return self.chargeCooldown <= 0 and self:playerInFront()
end

function BigHelmet:playerInFront()
    local player = self:getPlayer()

    if not player then return false end
    local px, py = player:getPosition()   -- your player sprite
    local bx, by = self:getPosition()

    -- both centers are (0,0), so these are top-left; compare centers instead
    local bossCenterX = bx + 24
    local bossCenterY = by + 16
    local dx = px - bossCenterX
    local dy = py - bossCenterY

    local inFront = (self.facing == 1 and dx > 0) or (self.facing == -1 and dx < 0)
    return inFront
        and math.abs(dx) <= CHARGE_RANGE
        and math.abs(dy) <= VERTICAL_TOLERANCE
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

function ChargeState:enter(boss)
    boss:changeState("charge") -- animation state
    boss.chargeCooldown = CHARGE_COOLDOWN_TIME
    boss.chargeTimer = CHARGE_FRAMES
    boss.xVelocity = boss.facing * boss.chargeSpeed
end

function ChargeState:update(boss)
    boss:updateAnimation()
    boss:updateFacing()
    local prevX, prevY = boss:getPosition()
    boss:applyGravity()
    local hitWall = boss:moveAndCollide(prevX, prevY)
    
    boss.chargeTimer -= 1
    -- exit the charge state

    if hitWall or boss.chargeTimer <= 0 then
        boss.chargeCooldown = CHARGE_COOLDOWN_TIME
        boss.fsm:change("patrol")
    end
end

function BigHelmet:setupAnimations()
    BigHelmet.super.setupAnimations(self)
    self:addState("charge", 1, 2, {tickStep = 2})
end
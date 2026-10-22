local gfx <const> = playdate.graphics

--- @class PatrolEnemy : Enemy
PatrolEnemy = {}
class("PatrolEnemy").extends(Enemy)

PatrolEnemy.PATROL_ENEMY_SHEET = "images/enemies/enemy-table-16-16"
local SIZE <const> = 16

PatrolEnemy.DEBUG = false
local debugProbes = {}

function PatrolEnemy:update()
    self:checkLedge()

    local prevX, prevY = self:getPosition()
    PatrolEnemy.super.update(self)
    -- check if enemy is a ledge check to control direction since having both breaks the patrol
    if not self.isLedgeEnemy then
        self:patrol(prevX, prevY)
    end
end

-- Returns true if there is solid ground just ahead of the leading foot
function PatrolEnemy:isGroundAhead()
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

    if PatrolEnemy.DEBUG then
        debugProbes[#debugProbes + 1] = { x = probeX, y = probeY, found = found }
    end
    return found
end

-- Call after gfx.sprite.update() while the camera draw offset is active.
-- Filled square = ground found, hollow square = no ground (enemy will turn around).
function PatrolEnemy.drawDebug()
    gfx.setColor(gfx.kColorXOR)
    for i = 1, #debugProbes do
        local p = debugProbes[i]
        if p.found then
            gfx.fillRect(p.x - 2, p.y - 2, 5, 5)
        else
            gfx.drawRect(p.x - 2, p.y - 2, 5, 5)
        end
    end
    debugProbes = {}
end

function PatrolEnemy:checkLedge()
    -- only ground walkers that are currently standing on something
    if not self.affectedByGravity or not self.onGround or self.xVelocity == 0 then
        return
    end

    if not self:isGroundAhead() then
        self.xVelocity *= -1
        self.distanceTraveled = 0
    end
   
end

function PatrolEnemy:patrol(prevX, prevY)
    local x, y = self:getPosition()

    local dx, dy = x - prevX, y - prevY
    self.distanceTraveled += math.sqrt(dx * dx + dy * dy)

    if self.maxDistance and self.maxDistance > 0 and self.distanceTraveled >= self.maxDistance then
        self.xVelocity *= -1
        if not self.affectedByGravity then self.yVelocity *= -1 end
        self.distanceTraveled = 0
    end
end
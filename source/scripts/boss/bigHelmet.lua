local gfx <const> = playdate.graphics

--- @class BigHelmet : Boss
BigHelmet = {}
class('BigHelmet').extends(Boss)

local SIZE <const> = 48

local CHARGE_RANGE <const> = 160   -- how far ahead the boss can see
local VERTICAL_TOLERANCE <const> = 24  -- player must be roughly on the boss's level
local CHARGE_COOLDOWN_TIME =  90

local CRASH_PAUSE_FRAMES <const> = 30   -- boss sits still after a charge (~1s at 30 fps)
local TURN_PAUSE_FRAMES <const> = 10    -- short beat after flipping before it walks off
local CRASH_SHAKE_MAGNITUDE <const> = 6
local CRASH_SHAKE_FRAMES <const> = 15
local SHEET <const> = "images/bosses/test/mm_wheelie/MM-Wheelie-table-48-32"
local VULNERABLE_FRAMES <const> = 120  -- how long the boss stays stunned after a slam
local FLICKER_FRAMES <const> = 40      -- warning flicker at the end of the window
local FLICKER_INTERVAL <const> = 3
local SLAM_HITSTOP_FRAMES <const> = 6  -- quick freeze when a slam lands
local HIT_COOLDOWN <const> = 12        -- min frames between hit points lost while vulnerable
local ChargeState = {}
local CrashState = {}
local VulnerableState = {}

function BigHelmet:init(x, y, entity)
    BigHelmet.super.init(self, x, y, entity, SHEET)
    self:setCollideRect(0, 8, 48, 24) -- offset the hit box for player to hit more easily
    self.fsm:add("charge", ChargeState) -- attack states that only this boss has
    self.fsm:add("crash", CrashState)
    self.fsm:add("vulnerable", VulnerableState)

    -- hits taken while vulnerable keep the boss in that state instead of the generic hurt state
    local defaultOnDamaged = self.health.onDamaged
    self.health.onDamaged = function(current, max)
        if self:isVulnerable() then
            self.health.invulnerableTimer = HIT_COOLDOWN
        else
            defaultOnDamaged(current, max)
        end
    end
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

    local inFront = (self:moveDir() == 1 and dx > 0) or (self:moveDir() == -1 and dx < 0)
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

function BigHelmet:moveDir()
    if self.xVelocity ~= 0 then
        self.lastMoveDir = self.xVelocity < 0 and -1 or 1
    end
    return self.lastMoveDir or 1
end

function ChargeState:enter(boss)
    boss:changeState("charge") -- animation state
    boss.chargeDir = boss:moveDir()
    boss.xVelocity = boss.chargeDir * boss.chargeSpeed
end

-- Charges until the boss slams into a wall (the end of the room)
function ChargeState:update(boss)
    boss:updateAnimation()
    boss:updateFacing()
    local prevX, prevY = boss:getPosition()
    boss:applyGravity()
    local hitWall = boss:moveAndCollide(prevX, prevY)

    if hitWall then
        boss.fsm:change("crash")
    end
end

function CrashState:enter(boss)
    boss.xVelocity = 0
    boss.crashTimer = CRASH_PAUSE_FRAMES
    boss.turned = false
    -- after the pause it walks back the way it came
    boss.savedXVelocity = -boss.chargeDir * boss.walkSpeed

    local player = boss:getPlayer()
    local scene = player and player.gameManager
    if scene and scene.camera then
        scene.camera:shake(CRASH_SHAKE_MAGNITUDE, CRASH_SHAKE_FRAMES)
    end
end

function CrashState:update(boss)
    boss:applyGravity()
    boss:moveAndCollide(boss:getPosition())

    boss.crashTimer -= 1
    if boss.crashTimer > 0 then return end

    if not boss.turned then
        -- flip to face the way it will walk, then hold briefly before moving
        boss.turned = true
        boss.crashTimer = TURN_PAUSE_FRAMES
        boss:setFacing(boss.savedXVelocity < 0 and 1 or -1) -- same convention as Enemy:updateFacing
        return
    end

    boss.chargeCooldown = CHARGE_COOLDOWN_TIME
    boss.fsm:change("patrol")
    boss.xVelocity = boss.savedXVelocity
end

function VulnerableState:enter(boss)
    if boss.xVelocity ~= 0 then
        boss.savedXVelocity = boss.xVelocity
    end
    boss.xVelocity = 0
    boss.vulnerableTimer = VULNERABLE_FRAMES
    boss.canHurtPlayer = false
    boss:changeState("hurt")
end

function VulnerableState:update(boss)
    boss:updateAnimation()
    boss:applyGravity()
    boss:moveAndCollide(boss:getPosition())

    boss.vulnerableTimer -= 1
    if boss.vulnerableTimer <= FLICKER_FRAMES then
        boss:setVisible(math.floor(boss.vulnerableTimer / FLICKER_INTERVAL) % 2 == 0)
    end

    if boss.vulnerableTimer <= 0 then
        boss.fsm:change("patrol")
        -- resume the way it was walking before the slam (patrol's enter picks its own direction)
        local dir = (boss.savedXVelocity or 1) < 0 and -1 or 1
        boss.xVelocity = dir * boss.walkSpeed
    end
end

function VulnerableState:exit(boss)
    boss:setVisible(true)
    boss.canHurtPlayer = true
    boss:changeState("patrol")
end

function BigHelmet:isVulnerable()
    return self.fsm.currentName == "vulnerable"
end

-- Only a hit while vulnerable costs a hit point; the boss stays vulnerable until the timer runs out
function BigHelmet:hitWhileVulnerable()
    self.health:damage(1)
end

-- A normal stomp only hurts while vulnerable; otherwise it's a plain bounce
function BigHelmet:onStomped()
    if self:isVulnerable() then
        self:hitWhileVulnerable()
    end
    return true
end

function BigHelmet:onSlammed()
    if self:isVulnerable() then
        self:hitWhileVulnerable()
    elseif self.fsm.currentName == "patrol" or self.fsm.currentName == "charge" or self.fsm.currentName == "crash" then
        self.fsm:change("vulnerable")
        HitStop.start(SLAM_HITSTOP_FRAMES)
    end
    return {
        velocity = -8,
        xPush = 3,
    }
end


function BigHelmet:setupAnimations()
    BigHelmet.super.setupAnimations(self)
    self:addState("charge", 1, 2, {tickStep = 2})
end

function BigHelmet:nonDamageOrStunHit()
    self.canHurtPlayer = false
end
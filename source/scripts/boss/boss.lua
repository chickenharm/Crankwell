import "scripts/boss/bossHealth"
import "scripts/stateMachine/stateMachine"

local HIT_POINTS <const> = 3        -- default; override with an LDtk "hitPoints" field
local HURT_FRAMES <const> = 45      -- stun + blink time after each hit
local DEATH_FRAMES <const> = 40     -- time spent flashing before removal
local SPEED_PER_HIT <const> = 0.75  -- boss walks faster after each hit
local BLINK_INTERVAL <const> = 3

--------------------------------------------------------------------------------
-- States (plain tables; each receives the boss as `boss`)
--------------------------------------------------------------------------------

local PatrolState = {}

function PatrolState:enter(boss)
    boss:setVisible(true)
    boss:setCollisionsEnabled(true)
    boss.xVelocity = boss.facing * boss.walkSpeed
end

function PatrolState:update(boss)
    -- Enemy:update already handles gravity, walking and bouncing off walls
    boss:updatePatrol()
end

local HurtState = {}

function HurtState:enter(boss)
    boss.facing = boss.xVelocity < 0 and -1 or 1
    boss.xVelocity = 0
    boss.walkSpeed = boss.baseSpeed + (boss.health.max - boss.health.current) * SPEED_PER_HIT

    -- Pass-through while stunned so a side touch can't kill the player mid-hit
    boss:setCollisionsEnabled(false)
end

function HurtState:update(boss)
    boss:updateAnimation()
    boss:setVisible(math.floor(boss.health.invulnerableTimer / BLINK_INTERVAL) % 2 == 0)

    if not boss.health:isInvulnerable() then
        boss.fsm:change("patrol")
    end
end

local DyingState = {}

function DyingState:enter(boss)
    boss.xVelocity = 0
    boss.deathTimer = DEATH_FRAMES
    boss:setCollisionsEnabled(false)
end

function DyingState:update(boss)
    boss:updateAnimation()
    boss.deathTimer -= 1
    boss:setVisible(math.floor(boss.deathTimer / BLINK_INTERVAL) % 2 == 0)

    if boss.deathTimer <= 0 then
        Enemy.damageEnemy(boss) -- the normal Enemy death: disables collisions and removes the sprite
    end
end

--------------------------------------------------------------------------------
-- Boss
--------------------------------------------------------------------------------

--- @class Boss : Enemy
class('Boss').extends(Enemy)

-- Optional: point this at a bigger sheet and pass nil for sheetPath
-- Boss.DEFAULT_SHEET = "images/enemies/boss-table-32-32"
Boss.UNPROTECTED_FRAMES = 90  -- ~3s of vulnerability after a slam

function Boss:init(x, y, entity, sheetPath)
    -- Enemy:init adds the sprite itself, so don't call :add() again
    Boss.super.init(self, x, y, entity, sheetPath or Boss.DEFAULT_SHEET)

    self:setCollideRect(0, 0, 48, 32)

    local fields = entity.fields
    self.baseSpeed = math.abs(self.xVelocity)
    self.walkSpeed = self.baseSpeed
    self.facing = self.xVelocity < 0 and -1 or 1
    self.jumpProtected = true
    self.jumpProtectionTimer = 0

    self.health = BossHealth(fields.hitPoints or HIT_POINTS, HURT_FRAMES)
    self.health.onDamaged = function() self.fsm:change("hurt") end
    self.health.onDeath = function() self.fsm:change("dying") end

    self.fsm = StateMachine(self)
    self.fsm:add("patrol", PatrolState)
    self.fsm:add("hurt", HurtState)
    self.fsm:add("dying", DyingState)
    self.fsm:change("patrol")
end

function Boss:update()
    self.health:update()
    self:updateJumpProtection()
    -- stun is ticked by Enemy:update, which PatrolStat e runs
    self.fsm:update()
    if self.chargeCooldown and self.chargeCooldown > 0 then
        self.chargeCooldown -= 1
    end
end

-- A stomp or slam on an unprotected boss costs it one hit point. The real
-- death happens in DyingState once the health runs out.
function Boss:damageEnemy()
    if self:isStunned() then self:recoverFromStun() end
    self:changeState("hurt")
    self:restoreJumpProtection()
    self.health:damage(1)
end

-- Slamming only breaks the boss's jump protection for a short window
function Boss:removeJumpProtection()
    Boss.super.removeJumpProtection(self)
    self.jumpProtectionTimer = Boss.UNPROTECTED_FRAMES
end

function Boss:restoreJumpProtection()
    self.jumpProtected = true
    self.jumpProtectionTimer = 0
end

function Boss:updateJumpProtection()
    if self.jumpProtectionTimer > 0 then
        self.jumpProtectionTimer -= 1
        if self.jumpProtectionTimer == 0 then
            self:restoreJumpProtection()
        end
    end
end

function Boss:updatePatrol()
    Enemy.update(self)  -- stun, animation, movement hooks
end

function Boss:setupAnimations()
    self:addState("patrol", 1, 2, {tickStep = 4})
    self:addState("hurt", 6, 6)
end
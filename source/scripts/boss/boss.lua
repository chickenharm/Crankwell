import "scripts/boss/bossHealth"
import "scripts/stateMachine/stateMachine"

local gfx <const> = playdate.graphics

local HIT_POINTS <const> = 3
local HURT_FRAMES <const> = 45      -- stun + blink time after each hit
local DEATH_FRAMES <const> = 40     -- time spent flashing before removal
local BASE_SPEED <const> = 1
local SPEED_PER_HIT <const> = 0.75  -- boss gets faster as it gets hurt
local BLINK_INTERVAL <const> = 3

--------------------------------------------------------------------------------
-- States (plain tables; each receives the boss as `boss`)
--------------------------------------------------------------------------------

local PatrolState = {}

function PatrolState:enter(boss)
    boss:setVisible(true)
    boss:setCollisionsEnabled(true)
end

function PatrolState:update(boss)
    local _, _, collisions, length = boss:moveWithCollisions(boss.x + boss.direction * boss.speed, boss.y)
    for i = 1, length do
        if collisions[i].normal.x ~= 0 then
            boss.direction = -boss.direction
            break
        end
    end
end

local HurtState = {}

function HurtState:enter(boss)
    -- Hit 1 -> speed BASE + 0.75, hit 2 -> BASE + 1.5
    boss.speed = BASE_SPEED + (boss.health.max - boss.health.current) * SPEED_PER_HIT
    -- Let the player pass through while the boss is stunned so it can't be
    -- killed by the player's side collision during the i-frames.
    boss:setCollisionsEnabled(false)
end

function HurtState:update(boss)
    boss:setVisible(math.floor(boss.health.invulnerableTimer / BLINK_INTERVAL) % 2 == 0)

    if not boss.health:isInvulnerable() then
        boss.states:change("patrol")
    end
end

local DyingState = {}

function DyingState:enter(boss)
    boss.deathTimer = DEATH_FRAMES
    boss:setCollisionsEnabled(false)
end

function DyingState:update(boss)
    boss.deathTimer -= 1
    boss:setVisible(math.floor(boss.deathTimer / BLINK_INTERVAL) % 2 == 0)

    if boss.deathTimer <= 0 then
        -- Defer to Enemy's normal death handling (removal, score, drops...)
        Boss.super.die(boss)
    end
end

--------------------------------------------------------------------------------
-- Boss
--------------------------------------------------------------------------------

--- @class Boss
Boss = {}
class('Boss').extends(Enemy)

function Boss:init(x, y)
    -- ADJUST: match whatever Enemy:init expects
    Boss.super.init(self, x, y)

    self:setTag(TAGS.Enemy)
    self.direction = 1
    self.speed = BASE_SPEED

    self.health = BossHealth(HIT_POINTS, HURT_FRAMES)
    self.health.onDamaged = function() self.states:change("hurt") end
    self.health.onDeath = function() self.states:change("dying") end

    self.states = StateMachine(self)
    self.states:add("patrol", PatrolState)
    self.states:add("hurt", HurtState)
    self.states:add("dying", DyingState)
    self.states:change("patrol")
end

-- PlayerCollision calls enemy:die() on a stomp / power slam, so a "death"
-- request from the player just means "take one hit". The real death happens
-- in DyingState once health reaches 0.
function Boss:die()
    self.health:damage(1)
end

-- Overlap with the player (so PlayerCollision decides stomp vs. death), slide on everything else.
function Boss:collisionResponse(other)
    if other:isa(Player) then
        return gfx.sprite.kCollisionTypeOverlap
    end
    return gfx.sprite.kCollisionTypeSlide
end

-- Playdate calls this automatically each frame for sprites in the display list
function Boss:update()
    self.health:update()
    self.states:update()
end
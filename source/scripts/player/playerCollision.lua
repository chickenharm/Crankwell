local gfx <const> = playdate.graphics

local BOUNCE_VELOCITY <const> = -6
local STOMP_GRACE_FRAMES <const> = 6
local LANDING_GRACE_PIXELS <const> = 6

-- default bounce values
local DEFAULT_BOUNCE <const> = {
    velocity = BOUNCE_VELOCITY,
    graceFrames = STOMP_GRACE_FRAMES,
}
--- @class PlayerCollision
PlayerCollision = {}
class('PlayerCollision').extends()

function PlayerCollision:init(player)
    self.player = player
    self.stompGrace = 0
end

function PlayerCollision:getResponse(other)
    local tag = other:getTag()
    if tag == TAGS.Hazzard or tag == TAGS.Enemy 
    or tag == TAGS.Pickup or tag == TAGS.Checkpoint then
        return gfx.sprite.kCollisionTypeOverlap
    end

    -- Breakable blocks are solid until the player slams into them, at which point
    -- the player should pass through (the block removes itself in moveAndCollide).
    if tag == TAGS.Breakable and self.player.slam:isPowerSlamming() then
        return gfx.sprite.kCollisionTypeOverlap
    end

    return gfx.sprite.kCollisionTypeSlide
end

-- Moves the player by its velocity and applies the results of any collisions
function PlayerCollision:moveAndCollide()

    -- prevent player from dying from jumping on a boss
    if self.stompGrace > 0 then self.stompGrace -= 1 end

    local player = self.player
    local _, _, collisions, length = player:moveWithCollisions(player.x + player.xVelocity, player.y + player.yVelocity)

    player.touchingGround = false
    player.touchingCeiling = false
    player.touchingWall = false
    local died = false
    -- moveWithCollisions can report the same enemy twice in one landing (e.g. a
    -- corner hit yields both a vertical and a horizontal normal), so track which
    -- enemies were already hit this frame to guarantee one stomp/slam per landing.
    local hitEnemies = {}

    for i = 1, length do
        local collision = collisions[i]
        local other = collision.other

        if collision.type == gfx.sprite.kCollisionTypeSlide then
            self:handleSurfaceCollision(collision)
        end

        if other:isa(Enemy) then
            if not hitEnemies[other] then
                hitEnemies[other] = true
                self:handleEnemyCollision(other, collision)
            end
        elseif other:isa(KeyDoor) then
            other:tryUnlock(player)
        elseif other:isa(Switch) and collision.normal.y == -1 then
            other:onJumpedOn(player)
            self:bouncePlayer()
        elseif other:getTag() == TAGS.Hazzard then
            died = true
        elseif other:getTag() == TAGS.Pickup then
            other:pickUp(player)
        elseif other:getTag() == TAGS.Breakable then
            if self.player.slam:isPowerSlamming() then
                other:breakBlock() 
            end
        end
    end

    player.grounded = player.touchingGround

    if died then
        player:die()
    end
end

function PlayerCollision:handleSurfaceCollision(collision)
    local player = self.player

    if collision.normal.y == -1 then
        player.touchingGround = true
        player.doubleJumpAvailable = true
    elseif collision.normal.y == 1 then
        player.touchingCeiling = true
    end

    if collision.normal.x ~= 0 then
        player.touchingWall = true
    end
end

-- Counts a clipped corner/side hit as a landing when the player is falling (or
-- slamming) and their feet are within a few pixels of the enemy's top.
function PlayerCollision:isLandingOnEnemy(enemy, collision)
    if collision.normal.y == -1 then return true end
    if collision.normal.y == 1 then return false end

    local player = self.player
    local falling = player.yVelocity > 0 or player.slam:isPowerSlamming()
    if not falling then return false end

    -- getCollideBounds is relative to the sprite, so convert to world coordinates
    local _, playerRy, _, playerRh = player:getCollideBounds()
    local _, playerSpriteY = player:getBounds()
    local playerBottom = playerSpriteY + playerRy + playerRh

    local _, enemyRy = enemy:getCollideBounds()
    local _, enemySpriteY = enemy:getBounds()
    local enemyTop = enemySpriteY + enemyRy

    return playerBottom <= enemyTop + LANDING_GRACE_PIXELS
end

function PlayerCollision:handleEnemyCollision(enemy, collision)
    if self:isLandingOnEnemy(enemy, collision) then
        local slam = self.player.slam
        local bounce
        if slam:isPowerSlamming() then
            bounce = enemy:onSlammed()
            slam.slamPhase = nil
            slam.powered = false
        else
            bounce = enemy:onStomped()
        end
        if bounce then
            -- `true` means default bounce; a table means custom profile
            self:bouncePlayer(type(bounce) == "table" and bounce or nil)
        end
    elseif enemy.canHurtPlayer and self.stompGrace <= 0 then
        self.player:die()
    end
end

-- bounce upwards; `profile` is optional and falls back to the default
function PlayerCollision:bouncePlayer(profile)
    profile = profile or DEFAULT_BOUNCE

    local velocity = profile.velocity or DEFAULT_BOUNCE.velocity
    self.player.yVelocity = velocity
    -- horizontal movement if necessary
    self.player.xVelocity += (profile.xPush or 0)
    self.stompGrace = profile.graceFrames or DEFAULT_BOUNCE.graceFrames

    if profile.onBounce then
        profile.onBounce(self.player)
    end
end
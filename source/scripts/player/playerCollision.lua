local gfx <const> = playdate.graphics

local STOMP_BOUNCE_VELOCITY <const> = -6

--- @class PlayerCollision
PlayerCollision = {}
class('PlayerCollision').extends()

function PlayerCollision:init(player)
    self.player = player
end

function PlayerCollision:getResponse(other)
    local tag = other:getTag()
    if tag == TAGS.Hazzard or tag == TAGS.Enemy or tag == TAGS.Pickup then
        return gfx.sprite.kCollisionTypeOverlap
    end

    return gfx.sprite.kCollisionTypeSlide
end

-- Moves the player by its velocity and applies the results of any collisions
function PlayerCollision:moveAndCollide()
    local player = self.player
    local _, _, collisions, length = player:moveWithCollisions(player.x + player.xVelocity, player.y + player.yVelocity)

    player.touchingGround = false
    player.touchingCeiling = false
    player.touchingWall = false
    local died = false

    for i = 1, length do
        local collision = collisions[i]
        local other = collision.other

        if collision.type == gfx.sprite.kCollisionTypeSlide then
            self:handleSurfaceCollision(collision)
        end

        if other:isa(Enemy) then
            self:handleEnemyCollision(other, collision)
        elseif other:getTag() == TAGS.Hazzard then
            died = true
        elseif other:getTag() == TAGS.Pickup then
            other:pickUp(player)
        elseif other:getTag() == TAGS.Breakable then
            -- add breakable code here
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

function PlayerCollision:handleEnemyCollision(enemy, collision)
    if enemy.isCrushable and collision.normal.y == -1 then
        enemy:die()
        self.player.yVelocity = STOMP_BOUNCE_VELOCITY
    else
        self.player:die()
    end
end

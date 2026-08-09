local pd <const> = playdate
local gfx <const> = playdate.graphics

import 'AnimatedSprite.lua'


--- @class Player : AnimatedSprite
Player = {}
class('Player').extends(AnimatedSprite)

function Player:init(x, y)

    -- state machine
    local playerImageTable = gfx.imagetable.new("images/Fox/player-table-16-16")
    Player.super.init(self, playerImageTable)

    self:addState("idle", 1, 1)
    self:addState("run", 1, 3, {tickStep = 4})
    self:addState("jump", 4, 4)
    self:playAnimation()

    -- sprite stuff
    self:moveTo(x, y)
    self:setZIndex(Z_INDEXES.Player)
    self:setTag(TAGS.Player)
    self:setCollideRect(3, 3, 10, 13)

    --physics
    self.xVelocity = 0
    self.yVeclocity = 0
    self.gravity = 1.0
    self.maxSpeed = 2.0
end


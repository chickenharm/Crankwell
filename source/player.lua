local pd <const> = playdate
local gfx <const> = playdate.graphics

import 'AnimatedSprite.lua'


class('Player').extends(AnimatedSprite)

function Player:init(x, y)
    local playerImage =
--- @class PlayerApexGlide
PlayerApexGlide = {}
class('PlayerApexGlide').extends()

-- Apex glide properties
local APEX_GLIDE_HOLD_FRAMES = 3

function PlayerApexGlide:init()
    self.apexGliding = false
    self.apexGliderTimer = 0
    self.apexPending = false
end

function PlayerApexGlide:resetApexGlide()
    self.apexGliding = false
    self.apexGliderTimer = 0
    self.apexPending = false
end

function PlayerApexGlide:rechargeApexGlideTimer()
    self.apexGliderTimer = APEX_GLIDE_HOLD_FRAMES
end

function PlayerApexGlide:updateApexPendingFlag(value)
    self.apexPending = value
end

function PlayerApexGlide:updateApexGlidingFlag(value)
    self.apexGliding = value
end

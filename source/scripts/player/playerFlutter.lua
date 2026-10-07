-- Flutter properties
local FLUTTER_FUEL_MAX = 40
local FLUTTER_FUEL_REGEN_ON_LAND = true
local FLUTTER_APEX_HOLD_FRAMES = 3
local FLUTTER_LIFT_PIXELS = 32
local FLUTTER_LIFT_SPEED = -1.0
local FLUTTER_DROP_PIXELS = 16
local FLUTTER_DROP_SPEED = 2.4

--- @class PlayerFlutter
PlayerFlutter = {}
class('PlayerFlutter').extends()

function PlayerFlutter:init(player)
    self.player = player

        -- flutter state
    self.fluttering = false
    self.flutterFuel = FLUTTER_FUEL_MAX
    self.flutterApexHoldTimer = 0
    self.flutterLiftRemaining = 0
    self.flutterDropRemaining = 0
    self.flutterSequenceDone = false
end


function PlayerFlutter:cancelFlutterAndGlide(player)
    self.fluttering = false
    self.flutterApexHoldTimer = 0
    self.flutterLiftRemaining = 0
    self.flutterDropRemaining = 0
    player.apexGliding = false
    player.apexGliderTimer = 0
    player.apexPending = false
end

function PlayerFlutter:resetForJump()
    self.fluttering = false
    self.flutterSequenceDone = false
    self.flutterDropRemaining = 0
    self.flutterApexHoldTimer = 0
    self.flutterLiftRemaining = 0
end

function PlayerFlutter:refillFlutterFuel()
    self.flutterFuel = FLUTTER_FUEL_MAX
end

function PlayerFlutter:updateFlutterState(prevVy, player)
    self.fluttering = (not player.grounded) and self.flutterFuel > 0 and IsCrankingFast()

    if not self.fluttering then
        self.flutterDropRemaining = 0
        self.flutterApexHoldTimer = 0
        self.flutterLiftRemaining = 0
    end

    -- latch the apex event so it survives past the single frame it occurs on
    if prevVy < 0 and (prevVy + player.gravity) >= 0 then
        player.apexPending = true
    end

  
    if self.fluttering and (not self.flutterSequenceDone) and player.apexPending then
        self.flutterDropRemaining = FLUTTER_DROP_PIXELS
        self.flutterApexHoldTimer = 0
        self.flutterLiftRemaining = FLUTTER_LIFT_PIXELS
        player.apexPending = false
    end

    -- apex glide: brief hover at the top of a normal (non-flutter) jump, canceled by fluttering
    if self.fluttering then
        player.apexGliding = false
        player.apexGliderTimer = 0
    elseif player.apexPending and (not player.grounded) and (not player.apexGliding) then
        player.apexGliding = true
        player:resetApexGlideTimer()
    end

    if player.apexGliding then
        player.yVelocity = 0
        player.apexGliderTimer -= 1
        if player.apexGliderTimer <= 0 then
            player.apexGliding = false
            player.apexPending = false -- grace window closed without a flutter start
        end
        return
    end

    -- Phase 1: short drop
    if self.flutterDropRemaining > 0 and self.fluttering then
        player.yVelocity = FLUTTER_DROP_SPEED
        self.flutterDropRemaining -= FLUTTER_DROP_SPEED
        self.flutterFuel -= 1

        if self.flutterDropRemaining <= 0 then
            self.flutterDropRemaining = 0
            self.flutterApexHoldTimer = FLUTTER_APEX_HOLD_FRAMES
        end

    -- Phase 2 hold position
    elseif self.flutterApexHoldTimer > 0 then
        player.yVelocity = 0
        self.flutterApexHoldTimer -= 1

    -- Phase 3: move up
    elseif self.flutterLiftRemaining > 0 and self.fluttering then
        player.yVelocity = FLUTTER_LIFT_SPEED
        self.flutterLiftRemaining -= math.abs(FLUTTER_LIFT_SPEED)
        self.flutterFuel -= 1

        if self.flutterLiftRemaining <= 0 then
            self.flutterLiftRemaining = 0
            self.flutterSequenceDone = true
        end

    elseif (not player.grounded) or player.yVelocity < 0 then
        player:addGravityForce()
    else
        player.yVelocity = 0
    end
end

function PlayerFlutter:handleLanding(wasGrounded)
    if (not wasGrounded) and FLUTTER_FUEL_REGEN_ON_LAND then
        self.flutterFuel = FLUTTER_FUEL_MAX
    end
        self.fluttering = false
        self.flutterApexHoldTimer = 0
        self.flutterLiftRemaining = 0
        self.flutterDropRemaining = 0
        self.flutterSequenceDone = false
end

function PlayerFlutter:handleConsumeJump()
        self.fluttering = false
        self.flutterApexHoldTimer = 0
        self.flutterLiftRemaining = 0
        self.flutterDropRemaining = 0
        self.flutterSequenceDone = false
end

function PlayerFlutter:updateFlutterFuel()
     if self.flutterFuel < 0 then
        self.flutterFuel = 0
    end
end

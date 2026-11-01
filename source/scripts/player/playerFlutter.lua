-- Flutter properties
-- one full flutter (drop + lift) costs ~39 fuel and fuel is refilled each time a flutter starts;
-- global so the HUD in main.lua shares it
FLUTTER_FUEL_MAX = 40
local FLUTTER_FUEL_REGEN_ON_LAND = true
local FLUTTER_APEX_HOLD_FRAMES = 3
local FLUTTER_LIFT_PIXELS = 32
local FLUTTER_LIFT_SPEED = -1.0
local FLUTTER_DROP_PIXELS = 16
local FLUTTER_DROP_SPEED = 2.4
-- airborne frames after a flutter ends (finished or released) before another full flutter can start
local FLUTTER_COOLDOWN_FRAMES = 20

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
    self.flutterActive = false
    self.flutterCooldown = 0
end


function PlayerFlutter:cancelFlutterAndGlide()
    self.fluttering = false
    self.flutterActive = false
    self.flutterCooldown = 0
    self.flutterApexHoldTimer = 0
    self.flutterLiftRemaining = 0
    self.flutterDropRemaining = 0
    self.player.apexGlide:resetApexGlide()
end

function PlayerFlutter:resetForJump()
    self.fluttering = false
    self.flutterActive = false
    self.flutterCooldown = 0
    self.flutterSequenceDone = false
    self.flutterDropRemaining = 0
    self.flutterApexHoldTimer = 0
    self.flutterLiftRemaining = 0
end

function PlayerFlutter:refillFlutterFuel()
    self.flutterFuel = FLUTTER_FUEL_MAX
end

function PlayerFlutter:updateFlutterState(prevVy, player)
    -- latch the apex event so it survives past the single frame it occurs on
    if prevVy < 0 and (prevVy + player:currentGravity()) >= 0 then
        player.apexGlide:updateApexPendingFlag(true)
    end

    local cranking = (not player.grounded) and IsCrankingFast()

    -- later flutters need the cooldown to run out
    if self.flutterSequenceDone and (not self.flutterActive) and (not player.grounded) and self.flutterCooldown > 0 then
        self.flutterCooldown -= 1
    end

    -- the first flutter starts at a jump's apex or any time the player is falling (e.g. off a ledge);
    -- later ones need the cooldown to run out
    local canStart = cranking and (not self.flutterActive) and
        ((not self.flutterSequenceDone and (player.apexGlide.apexPending or player.yVelocity > 0)) or
         (self.flutterSequenceDone and self.flutterCooldown <= 0))

    -- every flutter is a full one: fuel is not carried over from a flutter that was released early
    if canStart then
        self.flutterActive = true
        self.flutterFuel = FLUTTER_FUEL_MAX
        self.flutterDropRemaining = FLUTTER_DROP_PIXELS
        self.flutterApexHoldTimer = 0
        self.flutterLiftRemaining = FLUTTER_LIFT_PIXELS
        player.apexGlide:updateApexPendingFlag(false)
    end

    self.fluttering = cranking and self.flutterFuel > 0

    if not self.fluttering then
        -- released or out of fuel mid-flutter: the flutter is spent, start the cooldown
        if self.flutterActive then
            self.flutterActive = false
            self.flutterSequenceDone = true
            self.flutterCooldown = FLUTTER_COOLDOWN_FRAMES
        end
        self.flutterDropRemaining = 0
        self.flutterApexHoldTimer = 0
        self.flutterLiftRemaining = 0
    end

    -- apex glide: brief hover at the top of a normal (non-flutter) jump, canceled by fluttering
    if self.fluttering then
        player.apexGlide:updateApexGlidingFlag(false)
        player.apexGlide.apexGliderTimer = 0
    elseif player.apexGlide.apexPending and (not player.grounded) and (not player.apexGlide.apexGliding) then
        player.apexGlide:updateApexGlidingFlag(true)
        player.apexGlide:rechargeApexGlideTimer()
    end

    if player.apexGlide.apexGliding then
        player.yVelocity = 0
        player.apexGlide.apexGliderTimer -= 1
        if player.apexGlide.apexGliderTimer <= 0 then
            player.apexGlide:updateApexGlidingFlag(false)
            player.apexGlide:updateApexPendingFlag(false)
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
            self.flutterActive = false
            self.flutterSequenceDone = true
            self.flutterCooldown = FLUTTER_COOLDOWN_FRAMES
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
        self.flutterActive = false
        self.flutterCooldown = 0
        self.flutterApexHoldTimer = 0
        self.flutterLiftRemaining = 0
        self.flutterDropRemaining = 0
        self.flutterSequenceDone = false
end

function PlayerFlutter:handleConsumeJump()
        self.fluttering = false
        self.flutterActive = false
        self.flutterCooldown = 0
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

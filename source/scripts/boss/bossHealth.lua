--- Tracks hit points and a short invulnerability window after each hit.
--- Knows nothing about sprites, so it can be reused for any damageable thing.
--- @class BossHealth
BossHealth = {}
class('BossHealth').extends()

--- @param maxHealth integer hits needed to kill
--- @param invulnerableFrames integer frames of immunity after a non-lethal hit
function BossHealth:init(maxHealth, invulnerableFrames)
    self.max = maxHealth
    self.current = maxHealth
    self.invulnerableFrames = invulnerableFrames or 0
    self.invulnerableTimer = 0

    -- Assign these from the owner: function(current, max) / function()
    self.onDamaged = nil
    self.onDeath = nil
end

function BossHealth:isDead()
    return self.current <= 0
end

function BossHealth:isInvulnerable()
    return self.invulnerableTimer > 0
end

--- @return boolean true if the hit actually landed
function BossHealth:damage(amount)
    if self:isDead() or self:isInvulnerable() then
        return false
    end

    self.current = math.max(0, self.current - (amount or 1))

    if self.current == 0 then
        if self.onDeath then self.onDeath() end
    else
        self.invulnerableTimer = self.invulnerableFrames
        if self.onDamaged then self.onDamaged(self.current, self.max) end
    end
    return true
end

-- Call once per frame
function BossHealth:update()
    if self.invulnerableTimer > 0 then
        self.invulnerableTimer -= 1
    end
end
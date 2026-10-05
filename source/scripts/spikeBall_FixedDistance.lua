SpikeBall_FixedDistance = {}

class('SpikeBall_FixedDistance').extends(Spikeball)

function SpikeBall_FixedDistance:init(x, y, entity)
    SpikeBall_FixedDistance.super.init(self, x, y, entity)

    -- nil or 0 = no distance limit
    self.maxDistance = entity.fields.maxDistance
    self.distanceTraveled = 0
end

function SpikeBall_FixedDistance:update()
    local prevX, prevY = self.x, self.y
    local prevXVel, prevYVel = self.xVelocity, self.yVelocity

    -- original movement + wall-collision flip
    SpikeBall_FixedDistance.super.update(self)

    -- the parent flipped velocity, so a wall was hit: restart the count
    if self.xVelocity ~= prevXVel or self.yVelocity ~= prevYVel then
        self.distanceTraveled = 0
        return
    end

    local dx, dy = self.x - prevX, self.y - prevY
    self.distanceTraveled += math.sqrt(dx * dx + dy * dy)

    if self.maxDistance and self.maxDistance > 0 and self.distanceTraveled >= self.maxDistance then
        self.xVelocity *= -1
        self.yVelocity *= -1
        self.distanceTraveled = 0
    end
end
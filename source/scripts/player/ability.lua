
Ability = {}
class('Ability').extends(Collectible)

function Ability:init(x, y, entity)
  self.abilityName = entity.fields.ability
  Ability.super.init(self, x, y, entity, "images/PowerUps/" .. self.abilityName)
end

function Ability:onPickUp(player)
    if self.abilityName == "DoubleJump" then
        player.doubleJumpAbility = true
    end
end


Key = {}
class('Key').extends(Collectible)

function Key:init(x, y, entity)
    self.keyId = entity.fields.keyId
    Key.super.init(self, x, y, entity, "images/Items/Keys/" .. self.keyId)
end

function Key:onPickUp(player)
    -- inventory:add("key_" .. self.keyId)
end
---@class KeyDoor : Door
KeyDoor = {}
class('KeyDoor').extends(Door)

function KeyDoor:init(x, y, entity)
    self.keyId = entity.fields.Keys
    KeyDoor.super.init(self, x, y, entity)
end

function KeyDoor:tryUnlock(player)
    if player.inventory:consume("key_" .. self.keyId) then
        self:open()
        return true
    end
    return false
end
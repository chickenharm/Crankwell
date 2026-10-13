local gfx <const> = playdate.graphics

---@class SwitchDoor : Door
SwitchDoor = {}
class('SwitchDoor').extends(Door)

function SwitchDoor:init(x, y, entity)
    self.switchId = entity.fields.Switches
    SwitchDoor.super.init(self, x, y, entity)
end

--- called by a switch after player hits it
function SwitchDoor.openAll(switchId)
    for _, s in ipairs(gfx.sprite.getAllSprites()) do
        if s:isa(SwitchDoor) and s.switchId == switchId then
            s:open()
        end
    end
end
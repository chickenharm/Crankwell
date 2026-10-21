--- @class BigHelmet : Boss
BigHelmet = {}
class('BigHelmet').extends(Boss)

local SHEET <const> = "images/bosses/test/mm_wheelie/MM-Wheelie-table-48-32"

function BigHelmet:init(x, y, entity)
    BigHelmet.super.init(self, x, y, entity, SHEET)
    self:setCollideRect(0, 0, 48, 32)
    self.fsm:add("charge", ChargeState) -- attack states that only this boss has
end
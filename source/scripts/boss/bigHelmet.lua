--- @class BigHelmet : Boss
BigHelmet = {}
class('BigHelmet').extends(Boss)

local SHEET <const> = "images/bosses/test/MM-Wheelie-table-64-32"

function BigHelmet:init(x, y, entity)
    BigHelmet.super.init(self, x, y, entity, SHEET)
    self:setCollideRect(0, 0, 64, 32)
    self.fsm:add("charge", ChargeState) -- attack states that only this boss has
end
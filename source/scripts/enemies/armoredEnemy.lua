
---@class ArmoredEnemy : PatrolEnemy
ArmoredEnemy = {}
class("ArmoredEnemy").extends(PatrolEnemy)

ArmoredEnemy.SHEET = "images/enemies/armored-enemy-table-16-16"

function ArmoredEnemy:init(x, y, entity)
    ArmoredEnemy.super.init(self, x, y, entity, ArmoredEnemy.SHEET)
    self.jumpProtected = true
end
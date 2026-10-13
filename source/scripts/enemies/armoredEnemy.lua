
---@class ArmoredEnemy : PatrolEnemy
ArmoredEnemy = {}
class("ArmoredEnemy").extends(PatrolEnemy)

ArmoredEnemy.ARMORED_ENEMY_SHEET = "images/enemies/armoredEnemy/armored-enemy-table-16-16"

function ArmoredEnemy:init(x, y, entity)
    ArmoredEnemy.super.init(self, x, y, entity, ArmoredEnemy.ARMORED_ENEMY_SHEET)
    self.jumpProtected = true
end
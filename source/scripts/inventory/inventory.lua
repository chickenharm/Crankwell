import "CoreLibs/object"
import "CoreLibs/graphics"

local gfx <const> = playdate.graphics

Inventory = {}
class('Inventory').extends()

function Inventory:init(maxPerItem)
    Inventory.super.init(self)
    self.items = {}                      -- id -> count
    self.order = {}                      -- ids in pickup order (stable HUD layout)
    self.maxPerItem = maxPerItem or 99
    self.onChange = nil                  -- optional callback(id, newCount)
end

function Inventory:add(id, amount)
    amount = amount or 1
    local current = self.items[id] or 0
    if current == 0 then
        table.insert(self.order, id)
    end
    local new = math.min(current + amount, self.maxPerItem)
    self.items[id] = new
    if self.onChange then self.onChange(id, new) end
    return new - current                 -- how many were actually added
end

function Inventory:has(id, amount)
    return (self.items[id] or 0) >= (amount or 1)
end

function Inventory:count(id)
    return self.items[id] or 0
end

function Inventory:remove(id, amount)
    amount = amount or 1
    if not self:has(id, amount) then
        return false
    end
    local new = self.items[id] - amount
    if new == 0 then
        self.items[id] = nil
        for i, v in ipairs(self.order) do
            if v == id then
                table.remove(self.order, i)
                break
            end
        end
    else
        self.items[id] = new
    end
    if self.onChange then self.onChange(id, new) end
    return true
end

-- Check without consuming, then consume. Handy for doors.
function Inventory:consume(id, amount)
    return self:remove(id, amount)
end

function Inventory:clear()
    self.items = {}
    self.order = {}
end

-- Save/load
function Inventory:serialize()
    local out = {}
    for _, id in ipairs(self.order) do
        out[#out + 1] = { id = id, count = self.items[id] }
    end
    return out
end

function Inventory:deserialize(data)
    self:clear()
    for _, entry in ipairs(data or {}) do
        self:add(entry.id, entry.count)
    end
end

-- Simple HUD: icon + count per item
function Inventory:draw(x, y, icons)
    local cursor = x
    for _, id in ipairs(self.order) do
        local icon = icons[id]
        if icon then
            icon:draw(cursor, y)
            local w = icon:getSize()
            gfx.drawText("x" .. self.items[id], cursor + w + 2, y)
            cursor += w + 30
        end
    end
end
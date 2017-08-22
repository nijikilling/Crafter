local inventory_controller = {}

local world_mock = require("world_mock")
local robot = require("robot")
local inventory = require("inventory")

function inventory_controller.getInventorySize(side)
  local obj = world_mock.get_object_by_pos(robot.get_adjanced_pos(side))
  if (obj == nil) then return 0 end
  if (obj.inv == nil) then return 0 end
  return obj.inv.n or 0
end

local function getStackInInventorySlot(inv, slot)
  if (inv == nil) then return nil end
  if (inv[slot] == nil) then return nil end
  local res = {damage = 1, maxDamage = 1, size = inv[slot].count, 
               maxSize = inventory.stack_size(inv[slot].label),
               id = 22228, name = "minecraft:nil", label = inv[slot].label, hasTag = "false"}
  return res
end

function inventory_controller.getStackInSlot(side, slot)
  local obj = world_mock.get_object_by_pos(robot.get_adjanced_pos(side))
  if (obj == nil) then return nil end
  return getStackInInventorySlot(obj.inv, slot)
end

function inventory_controller.getStackInInternalSlot(slot)
  return getStackInInventorySlot(robot.inv, slot)
end

function inventory_controller.dropIntoSlot(side, slot)
  local obj = world_mock.get_object_by_pos(robot.get_adjanced_pos(side))
  if (obj == nil) then return false end
end

return inventory_controller
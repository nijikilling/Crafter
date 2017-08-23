local crafting = {}

local world_mock = require("world_mock")
local robot = require("robot")
local inventory = require("inventory")

function crafting.craft(count)
  count = math.min(count, 64)
  local inv = robot.inv
  local indexes = {1, 2, 3, 5, 6, 7, 9, 10, 11}
  local ingred_table = {}
  local min_slot_count = 64
  for _, i in ipairs(indexes) do
    local cur_ingred = {}
    cur_ingred.id = robot.inv[i].label
    min_slot_count = math.min(robot.inv:get_slot(i):get_count() or 64, min_slot_count)
  end
  for _, recipe in ipairs(world_mock.recipes) do
    local q = true
    for i, ingred in ipairs(recipe["ingredients"]) do --searching recipe
      if (ingred.id ~= ingred_table[i].id) then 
        q = false
      end
    end
    if (q == true) then
      --recipe found with such ingreds
      local output_size = 0
      for key, val in pairs(recipe["output"]) do
        output_size = math.max(output_size, val)
      end
      local times_crafted = math.min(min_slot_count, count / output_size)
      for _, i in ipairs(indexes) do
        if (robot.inv:get_slot(i):get_id() ~= nil) then
          robot.inv[i]:get_slot(i):takeaway(times_crafted)
        end
      end
      for key, val in pairs(recipe["output"]) do
        robot.inv:receive(
          inventory.c_slot.new({["id"] = key, ["count"] = val * output_size}), 
          robot.select())
      end
      return true
    end
  end
  return false
end

return crafting
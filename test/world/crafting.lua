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
    cur_ingred.id = inv:get_slot(i):get_id()
    cur_ingred.count = inv:get_slot(i):get_count()
    if (cur_ingred.count ~= 0) then
      min_slot_count = math.min(cur_ingred.count, min_slot_count)
    end
    table.insert(ingred_table, cur_ingred)
  end
  local recipes_table = world_mock.load_recipes()
  for _, recipe in ipairs(recipes_table) do
    local q = true
    for i, ingred in ipairs(recipe:get_ingredients()) do --searching recipe
      if (ingred.id ~= ingred_table[i].id) then 
        q = false
      end
    end
    if (q == true) then
      --recipe found with such ingreds
      local output_size = 0
      for key, val in pairs(recipe:get_output()) do
        output_size = math.max(output_size, val)
      end
      local times_crafted = math.min(min_slot_count, math.floor(count / output_size + 0.0001))
      for _, i in ipairs(indexes) do
        if (inv:get_slot(i):get_id() ~= nil) then
          inv:get_slot(i):takeaway(times_crafted)
        end
      end
      for key, val in pairs(recipe:get_output()) do
        inv:receive(
          inventory.c_slot.new({["id"] = key, ["count"] = val * times_crafted}), 
          val * times_crafted,
          robot.select())
      end
      return true
    end
  end
  return false
end

return crafting
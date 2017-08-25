local world_mock = {}

local test_utils = require("test_utils")
local serialization = require("serialization")
local inventory = require("inventory")

world_mock.c_recipe = { }
world_mock.c_recipe.mt = { }

world_mock.c_recipe.mt.__eq = function (a, b)
  test_utils.raise_error("trying to compare recipes, which is not implemented")
  return nil
end

world_mock.c_recipe.mt.__metatable = "not today"

world_mock.c_recipe.mt.__index = function (table, key)
  local res = rawget(world_mock.c_recipe, key)
  if (res == nil) then 
    test_utils.raise_error("nil called in world_mock!") 
  end
  return res
end

function world_mock.c_recipe.new()
  local res = {}
  setmetatable(res, world_mock.c_recipe.mt)
  return res
end

function world_mock.c_recipe.set_machine(recipe, machine_data)
  recipe["machine"] = {}
  for _, key in ipairs({"id", "tier", "needs_reinstall", "duration"}) do
      recipe["machine"][key] = machine_data[key]
  end
  return recipe
end

function world_mock.c_recipe.add_ingredient(recipe, ingredient_data)
  recipe["ingredients"] = rawget(recipe, "ingredients") or {}
  local new_ingred = {}
  for _, key in ipairs({"id", "count", "type"}) do
    new_ingred[key] = ingredient_data[key]
  end
  table.insert(recipe["ingredients"], new_ingred)
  return recipe
end

function world_mock.c_recipe.set_output(recipe, output_data)
  recipe["output"] = output_data
  return recipe
end

function world_mock.c_recipe.get_ingredients(recipe)
  return recipe["ingredients"]
end

function world_mock.c_recipe.get_output(recipe)
  return recipe["output"]
end

world_mock.objects = {}
--[[
world object is:
--type(machine, solid, chest, tank, creature)
--label
--inv, tank, hp, out_inv(only for machines!) (nil if has no)
--pos
--]]
world_mock.inv_links = {}
world_mock.recipes = {}

function world_mock.add_object(object)
  table.insert(world_mock.objects, object)
end

function world_mock.get_object_by_pos(pos)
  for _, val in ipairs(world_mock.objects) do
    if (pos == val.pos) then
      return world_mock.deep_copy(val)
    end
  end
end

function world_mock.equal_objects(a, b)
  if (type(a) ~= type(b)) then return false end
  if (type(a) ~= "table") then return a == b end
  for key, val in pairs(a) do
    if (world_mock.equal_objects(val, b[key]) == false) then return false end
  end
  return true
end


function world_mock.erase_block(block)
  for i, val in ipairs(world_mock.objects) do
    if (world_mock.equal_objects(block, val) == true) then
      table.remove(world_mock.objects, i)
      return true
    end
  end
  return false, "not found"
end

function world_mock.get_object_blueprint_by_name(name)
  if (name == nil) then test_utils.raise_error("blueprint - nil name") end
  local res = {label = name}
  if (name == "Chest") then
    res.type = "chest"
    res.inv = inventory.construct_inventory(32)
  end
  if (name == "Tank") then
    res.type = "tank"
    res.tank = inventory.construct_tank(16000) --depend
  end
  if (name == "Compressor") then
    res.type = "machine"
    --inv and outer_inv are supplied by outside-referencing
  end
end

function world_mock.update_inv_links()
  for _, val in ipairs(world_mock.inv_links) do
    inventory.inv_link_update(val)
  end
end

function world_mock.load_recipes()
  world_mock.recipes = {}
  table.insert(world_mock.recipes, world_mock.c_recipe.new()
    :add_ingredient({id = "Wood", count = 1, ["type"] = "consumable"})
    :add_ingredient({id =    nil, count = 0, ["type"] = "consumable"})
    :add_ingredient({id =    nil, count = 0, ["type"] = "consumable"})
    :add_ingredient({id = "Wood", count = 1, ["type"] = "consumable"})
    :add_ingredient({id =    nil, count = 0, ["type"] = "consumable"})
    :add_ingredient({id =    nil, count = 0, ["type"] = "consumable"})
    :add_ingredient({id =    nil, count = 0, ["type"] = "consumable"})
    :add_ingredient({id =    nil, count = 0, ["type"] = "consumable"})
    :add_ingredient({id =    nil, count = 0, ["type"] = "consumable"})
    :set_machine({id = "Workbench", tier=nil, needs_reinstall = false, duration = 0})
    :set_output({["Stick"] = 2})
  )
  
  table.insert(world_mock.recipes, world_mock.c_recipe.new()
    :add_ingredient({id = "Wood", count = 1, ["type"] = "consumable"})
    :add_ingredient({id = "Wood", count = 1, ["type"] = "consumable"})
    :add_ingredient({id = "Wood", count = 1, ["type"] = "consumable"})
    :add_ingredient({id = "Wood", count = 1, ["type"] = "consumable"})
    :add_ingredient({id =    nil, count = 0, ["type"] = "consumable"})
    :add_ingredient({id = "Wood", count = 1, ["type"] = "consumable"})
    :add_ingredient({id = "Wood", count = 1, ["type"] = "consumable"})
    :add_ingredient({id = "Wood", count = 1, ["type"] = "consumable"})
    :add_ingredient({id = "Wood", count = 1, ["type"] = "consumable"})
    :set_machine({id = "Workbench", tier=nil, needs_reinstall = false, duration = 0})
    :set_output({["Chest"] = 1})
  )
  return world_mock.recipes
end

return world_mock
local world_mock = {}

local test_utils = require("test_utils")
local serialization = require("serialization")
local inventory = require("inventory")

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
    res.type == "chest"
    res.inv = inventory.construct_inventory(32)
  end
  if (name == "Tank") then
    res.type == "tank"
    res.tank = inventory.construct_tank(16000) --depend
  end
  if (name == "Compressor") then
    res.type == "machine"
    --inv and outer_inv are supplied by outside-referencing
  end
end

function world_mock.update_inv_links()
  for _, val in ipairs(world_mock.inv_links) do
    inventory.inv_link_update(val)
  end
end

function world_mock.load_recipes()
  local inf = test_utils.file_open_read("recipes.txt")
  world_mock.recipes = serialization.unserialize(test_utils.read_whole_file(inf))
  test_utils.close_file(inf)
  for ind, val in pairs(world_mock.recipes) do
    if (val["ingredients"]["recipe_string"] ~= nil) then
      local tmp = {}
      for i = 1, 9 do
        local sym = string.sub(val["ingredients"]["recipe_string"], i, i)
        table.insert(tmp, {
            ["id"] = val["ingredients"]["short_names"][sym], 
            ["amount"] = 1,
            ["consumable"] = "yes"
            })
      end
      world_mock.recipe_table[ind]["ingredients"] = tmp
    end
  end
  local outf = test_utils.file_open_write("recipes.txt")
  io.write(outf, serialization.serialize(world_mock.recipe_table))
  test_utils.close_file(outf)
end

return world_mock
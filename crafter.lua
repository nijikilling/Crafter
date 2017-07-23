local robot = require("robot")
local sides = require("sides")
local component = require("component")
local serialization = require("serialization")

local inv_cont = component.inventory_controller
local tank_cont = component.tank_controller
local crafting =component.crafting

local movement = {}
local chest_working = {}
local machines = {}
local utils = {}
local craft_work = {}


local gregtech_machine_name = "gregtech:gt.blockmachines"

local algo_state = "off"


--MOVEMENT


movement.directions = {{0, 1}, {-1, 0}, {0, -1}, {1, 0}}
movement.current_direction = 0
movement.cur_x = 0
movement.cur_y = 0
movement.cur_z = 0
movement.position_stack = {}
movement.common_chest_pos = nil
movement.temp_chest_pos = nil

function movement.move_with_errors_handling(n, move_function)
  
--does:    tries to apply move_function n times, handling some errors(i.m. trying to kill entities on the way, repeating action)
--returns: amount of steps done
  n = n or 1
  utils.log("movement", "called with n = " .. n)
  io.write(n)
  local i = 0
  local errors = 0
  while i < n do
    local success, str = move_function()
    if (success) then
      i = i + 1
    else
      errors = errors + 1
      if (errors >= 5) then
        return i, "unkillable"
      end
      if (str == "solid") then
        return i, "solid"
      else --entity
        kill_entity() --depend
      end
    end
  end
  utils.log("movement", "returned res = " .. n)
  return n, "success"
end

function movement.alg_modulo(n, mod)
  return (n + mod) % mod
end

function movement.update_relative_position(n, delta)
  utils.log("debug", n)
  --utils.log("debug", delta)
  --utils.log("debug", movement.alg_modulo(movement.current_direction + delta, 4) + 1)
  --utils.log("debug", movement.directions[movement.alg_modulo(movement.current_direction + delta, 4) + 1][1])
  movement.cur_x = movement.cur_x + 
    movement.directions[movement.alg_modulo(movement.current_direction + delta, 4) + 1][1] * n
  movement.cur_z = movement.cur_z + 
    movement.directions[movement.alg_modulo(movement.current_direction + delta, 4) + 1][2] * n
end

function movement.move_forward(n)
  local res, reason = movement.move_with_errors_handling(n, robot.forward)
  movement.update_relative_position(res, 0)
  return res, reason
end

function movement.move_back(n)
  local res, reason = movement.move_with_errors_handling(n, robot.back)
  movement.update_relative_position(res, 2)
  return res, reason
end

function movement.move_up(n)
  local res, reason = movement.move_with_errors_handling(n, robot.up)
  movement.cur_y = movement.cur_y + res
  return res, reason
end

function movement.move_down(n)
  local res, reason = movement.move_with_errors_handling(n, robot.down)
  utils.log("down_debug", res .. " " .. reason)
  utils.log("down_debug", movement.cur_y)
  movement.cur_y = movement.cur_y - res
  return res, reason
end

function movement.rotate_left()
  robot.turnLeft()
  movement.current_direction = movement.alg_modulo(movement.current_direction + 1, 4)
end

function movement.rotate_right()
  robot.turnRight()
  movement.current_direction = movement.alg_modulo(movement.current_direction - 1, 4)
end

function movement.rotate_back()
  --Rotates back
  robot.turnLeft()
  robot.turnLeft()
  movement.current_direction = movement.alg_modulo(movement.current_direction + 2, 4)
end

function movement.move_left(n)
  movement.rotate_left()
  local res, reason = movement.move_forward(n)
  movement.rotate_right()
  return res, reason
end

function movement.move_right(n)
  movement.rotate_right()
  local res, reason = movement.move_forward(n)
  movement.rotate_left()
  return res, reason
end

function movement.get_current_pos()
  return {["x"]=movement.cur_x, ["y"]=movement.cur_y, ["z"]=movement.cur_z, 
    ["orientation"]=movement.current_direction}
end

function movement.go_to_pos(pos)
  if (movement.current_direction == 3) then movement.rotate_right() end
  while movement.current_direction ~= 0 do movement.rotate_left() end
  local delta_x = pos["x"] - movement.cur_x
  local delta_y = pos["y"] - movement.cur_y
  local delta_z = pos["z"] - movement.cur_z
  local iter = 0
  while (delta_x ~= 0 or delta_y ~= 0 or delta_z ~= 0) do
    if (delta_x > 0) then delta_x = delta_x - movement.move_right(delta_x) end
    if (delta_x < 0) then delta_x = delta_x + movement.move_left(-delta_x) end
    
    if (delta_y > 0) then delta_y = delta_y - movement.move_up(delta_y) end
    if (delta_y < 0) then delta_y = delta_y + movement.move_down(-delta_y) end
    
    if (delta_z > 0) then delta_z = delta_z - movement.move_forward(delta_z) end
    if (delta_z < 0) then delta_z = delta_z + movement.move_back(-delta_z) end
    
    iter = iter + 1
    if (iter >= 10) then
      return false, "failed, unknown reasons" --ToDo log this shit
    end
  end
  if (pos["orientation"] == 1) then movement.rotate_right() end
  while movement.current_direction ~= pos["orientation"] do movement.rotate_left() end
  return true
end

function movement.remember_my_position()
  table.insert(movement.position_stack, movement.get_current_pos())
end

function movement.go_to_zero()
  return movement.go_to_pos({["x"]=0, ["y"]=0, ["z"]=0, ["orientation"]=0})
end

function movement.restore_my_position()
  return movement.go_to_pos(table.remove(movement.position_stack))
end

function movement.restore_y_coord()
  return movement.move_down(movement.cur_y)
end


--END OF MOVEMENT
--CHEST_WORKING


chest_working.reserved_slots = 1
chest_working.chest_name = "Сундук"
chest_working.wrench_name = "Wrench"
chest_working.time_to_reach_chest = 20

function chest_working.query_nonempty(query)
  for key, val in pairs(query) do
    if (val > 0) then return true end
  end
  return false
end


function chest_working.find_in_chest_by_name(query, lootAll)
  local n = inv_cont.getInventorySize(sides.front)
  lootAll = lootAll or false
  if (lootAll ~= false) then
    query[-1] = 100000
  else
    query[-1] = 0
  end
  for i = 1, n do
    local info = inv_cont.getStackInSlot(sides.front, i)
    if (info ~= nil) then
      if (query[info["label"]] == nil) then info["label"] = -1 end
      if (query[info["label"]] ~= nil) then 
        local am = info["size"]
        inv_cont.suckFromSlot(sides.front, i, utils.min(query[info["label"]], 64)) --ToDo custom stack sizes
        local new_info = inv_cont.getStackInSlot(sides.front, i) or {}
        local new_am = new_info["size"] or 0
        query[info["label"]] = query[info["label"]] - (am - new_am)
      end
    end
    if (chest_working.query_nonempty(query) == false) then break end
  end
  query[-1] = nil
  return nil, query
end

function chest_working.have_adjanced_inventory()
  local n = inv_cont.getInventorySize(sides.front)
  n = n or 0
  utils.log("debug_chest", "adjanced inventory size = " .. n)
  if (n == nil or n == 0) then return false end
  return true
end

function chest_working.calc_in_all_chests_by_name(name)
  local am = 0
  while (chest_working.have_adjanced_inventory()) do
    local n = inv_cont.getInventorySize(sides.front)
    for i = 1, n do
      local info = inv_cont.getStackInSlot(sides.front, i)
      if (info ~= nil) then
        if (info["label"] == name) then
          am = am + info["size"] or 0
        end
      end
    end
    movement.move_up()
  end
  movement.restore_y_coord()
  return am
end

--@pos-safe
function chest_working.get_item_in_chests_by_name(query, temp, lootAll)
  utils.log("get_item_in_chests", "called with query = " .. serialization.serialize(query) .. " and temp = " .. (temp or "nil")) 
  movement.remember_my_position()
  if (temp == nil or temp == false) then
    movement.go_to_pos(movement.common_chest_pos)
  else
    movement.go_to_pos(movement.temp_chest_pos)
  end
  local cont = true
  while (chest_working.have_adjanced_inventory() and cont == true) do
    local _, left = chest_working.find_in_chest_by_name(query, lootAll)
    query = left
    cont = chest_working.query_nonempty(query)
    if (cont == true) then
      movement.move_up()
    end
  end
  movement.restore_y_coord()
  if (cont == true) then
    for name, amount in pairs(query) do
      local _, left, needed_parts = craft_work.craft_items(name, amount) --depend only can be called for crafting tools
      query[name] = left
    end
    cont = chest_working.query_nonempty(query)
    if (cont == true) then
      utils.terminate_algo("can't find or craft needed amount of stuff")
      --ToDo log needed stuff
    end
  end
  movement.restore_my_position()
  return true, 0 
end

function chest_working.find_slot_by_name(name)
  local size = robot.inventorySize() - chest_working.reserved_slots
  for i = 1, size do
    local info = inv_cont.getStackInInternalSlot(i)
    if (info ~= nil) then
      utils.log("debug_slot", info["label"])
      utils.log("debug_slot", name)
      if (info["label"] == name) then --wanna IC2 compatibility
        return i
      end
    else
      if (name == nil) then
        return i
      end
    end
  end
  return nil
end

function chest_working.store_slot(slot, amount)
  while (amount > 0) do
    robot.select(slot)
    local old_val = robot.count()
    if (chest_working.have_adjanced_inventory() == false) then
      local success, left = chest_working.get_item_in_chests_by_name({[chest_working.chest_name] = 1}, false)
      utils.place_block_by_name(chest_working.chest_name)
    end
    robot.select(slot)
    robot.drop(amount)
    amount = amount - (old_val - robot.count())
    if (amount > 0) then
      movement.move_up()
    end
  end
end

function chest_working.store_all_items() --ToDo retest
  local internal_inv_size = robot.inventorySize() - chest_working.reserved_slots
  local index = 1
  for index = 1, internal_inv_size do
    robot.select(index)
    chest_working.store_slot(index, robot.count() or 0)
  end
  robot.select(1)
  return true
end

function chest_working.store_item_by_name(name, amount)
  local internal_inv_size = robot.inventorySize() - chest_working.reserved_slots
  local index = 1
  for index = 1, internal_inv_size do
    local slot_name, slot_amount = chest_working.inspect_slot(index)
    if (slot_name == name) then
      local k = utils.min(amount, slot_amount)
      chest_working.store_slot(index, k)
      amount = amount - k
      if (amount == 0) then
        break
      end
    end
  end
  
end

function chest_working.transfer_to_temporary_chests(name, amount) 
  movement.remember_my_position()
  movement.go_to_pos(movement.common_chest_pos)
  local last_amount = 0
  while (last_amount ~= amount) do
    last_amount = amount
    local _, left = chest_working.get_item_in_chests_by_name({name = amount}) --pos-safe
    amount = left
    if (amount ~= last_amount) then --ToDo depend rewrite for list-transfer too!
      movement.go_to_pos(movement.temp_chest_pos)
      chest_working.store_all_items()
      movement.go_to_pos(movement.common_chest_pos)
    end
  end
  movement.restore_my_position()
end

function chest_working.inventory_nonempty()
  local n = robot.inventorySize() - chest_working.reserved_slots
  for i = 1, n do
    local info = inv_cont.getStackInInternalSlot(i)
    if (info ~= nil) then return true end
  end
  return false
end

function chest_working.clear_temporary_chests()
  movement.remember_my_position()
  local robot_loots_something = true
  while(robot_loots_something == true) do
    movement.go_to_pos(movement.temp_chest_pos)
    while(chest_working.have_adjanced_inventory()) do
      chest_working.find_in_chest_by_name(" ", -1, true) --loot all from chest 
      movement.move_up()
    end
    robot_loots_something = chest_working.inventory_nonempty()
    movement.go_to_pos(movement.common_chest_pos)
    chest_working.store_all_items()
  end
  --ToDo return sth
end

function chest_working.take_from_chest_and_return(name, amount)
  movement.remember_my_position() 
  movement.go_to_pos(movement.common_chest_pos) 
  chest_working.get_item_in_chests_by_name({name = amount})
  movement.restore_my_position()
end

function chest_working.inspect_slot(ind)
  local info = inv_cont.getStackInInternalSlot(ind)
  if (info == nil) then
    return nil, nil, nil
  end
  return info["label"], info["size"]
end

function chest_working.swap_slots(i, j)
  local prev_selected = robot.select()
  robot.select(i)
  robot.transferTo(j)
  robot.select(prev_selected)
end

function chest_working.clear_slots(query_slots)
  utils.log("clear_slots", "called!")
  local inv_size = robot.inventorySize() - chest_working.reserved_slots
  local calc = {}
  local ind = 1
  local t_sz = 0
  local slots = {}
  for table_pos, i in pairs(query_slots) do
    local name, _, _ = chest_working.inspect_slot(i)
    calc[i] = 1
    if (name ~= nil) then
      t_sz = t_sz + 1
      table.insert(slots, table_pos)
    end
  end
  for i = 1, inv_size do
    if (calc[i] == nil) then
      local name, _, _ = chest_working.inspect_slot(i)
      if (name == nil) then
        chest_working.swap_slots(slots[ind], i)
        ind = ind + 1
        if (ind > t_sz) then return true end
      end
    end
  end
end

--END OF CHEST_WORKING
--MACHINES

machines.machines = {}

function machines.parse_machine_name(name) --ToDo parse special names
  local name_table = {
    {"Ultra Low Voltage", 1},
    {"Low Voltage", 2},
    {"Medium Voltage", 3},
    {"High Voltage", 4},
    {"Extreme Voltage", 5},
    {"Insane Voltage", 6},
    {"Ludicrous Voltage", 7},
    {"ZPM Voltage", 8},
    {"Ultimate Voltage", 9},
    {"MAX Voltage", 10},
    {"Basic", 2},
    {"Advanced", 3},
    {"ULV", 1},
    {"LV", 2},
    {"MV", 3},
    {"HV", 4},
    {"EV", 5},
    {"IV", 6},
    {"LuV", 7},
    {"ZPM", 8},
    {"UV", 9},
    {"Max", 10}
}

  local grade_table = {
    {"III", 2},
    {"II", 1},
    {"IV", 3},
    {"V", 4}
  }
  local l = string.len(name)
  local res = 0
  for _, tmp in pairs(name_table) do
    local key = tmp[1]
    local val = tmp[2]
    local i, j = string.find(string.sub(name, 1, l - 3), key)
    if (i ~= nil) then
      name = string.gsub(name, key, "", 1)
      res = res + val
      l = string.len(name)
    end
  end
  
  for _, tmp in pairs(grade_table) do
    local key = tmp[1]
    local val = tmp[2]
    local i, j = string.find(string.sub(name, l - 3, l), key)
    if (i ~= nil) then
      name = string.gsub(name, key, "", 1)
      res = res + val
      l = string.len(name)
    end
  end
  name = string.gsub(name, "  ", " ")
  if (string.sub(name, 1, 1) == " ") then
    name = string.sub(name, 2)
  end
  if (string.sub(name, string.len(name)) == " ") then
    name = string.sub(name, 1, -2)
  end
  return name, res
end

function machines.add_machine_by_name(name)
  local raw_name, voltage_tier = machines.parse_machine_name(name)
  local t = {["tier"]=voltage_tier, ["machine"]=raw_name, 
    ["x"]=movement.cur_x, ["y"]=movement.cur_y, ["z"]=movement.cur_z, 
    ["orientation"]=movement.current_direction}
  table.insert(machines.machines, t)
end

--@keep-select
function machines.fill_in_by_name(name, amount)
  utils.log("fill_in_by_name", name .. amount)
  local prev_selected = robot.select()
  while (amount > 0) do
    local last_amount = amount
    local p = chest_working.find_slot_by_name(name)
    local sz = inv_cont.getStackInInternalSlot(p)["size"]
    local k = utils.min(sz, amount)
    robot.select(p)
    robot.drop(k)
    amount = amount - k
    if (amount == last_amount) then
      utils.terminate_algo("Looks like either some ingredients were removed, or robot has too small inventory!")
    end
  end
  robot.select(prev_selected)
  utils.terminate_algo("test_terminate")
  return true
end

function machines.fill_in_ingredients(recipe_ingredients, first_time)
  utils.log("fill_in_ingredients", "called!")
  for _, ingredient in pairs(recipe_ingredients) do
    if ((ingredient["consumable"] == "no" and first_time) or ingredient["consumable"] == "yes") then
      machines.fill_in_by_name(ingredient["id"], ingredient["amount"])
    end
  end
end

function machines.get_machine_output()
  for _ = 1, 4 do   --ToDo for processing-type recipes this should be configured, because suck() takes only one slot of output. 
    robot.suck()
  end
end

function machines.search_machine_by_name_and_tier(name, tier)
  for _, machine in ipairs(machines.machines) do
    if (name == machine["machine"] and tier <= machine["tier"]) then
      return machine
    end
  end
  utils.terminate_algo("failed to find mechanism needed")
end

--@pos-safe
function machines.go_and_reinstall_machine(pos)
  local prev_selected = robot.select()
  movement.remember_my_position()
  movement.go_to_pos(pos)
  equip_tool_by_name(wrench_name) --ToDo make constant or enum
  pos = chest_working.find_slot_by_name(nil)
  robot.select(pos)
  machines.harvest_mechanism()
  robot.place(sides.front, true)
  movement.restore_my_position()
  robot.select(prev_selected)
end

function machines.harvest_mechanism()
  utils.equip_tool_by_name(chest_working.wrench_name)
  local success = robot.swing(sides.front)
  if (success) then robot.suck() end
  return success
end


--END OF MACHINES
--UTILS


function utils.terminate_algo(reason)
  movement.go_to_zero()
  print(reason)
  os.exit(-1)
end

function utils.file_open_read(name, default)
  local file = io.open(name, "r")
  if (file == nil) then
    file = io.open(name, "w")
    file.write(file, default)
    io.close(file)
  end
  file = io.open(name, "r")
  if(file == nil) then
    utils.terminate_algo("can't create file!")
  end
  return file
end

function utils.file_open_write(name)
  local file = io.open(name, "w")
  if (file == nil) then
    utils.terminate_algo("can't create file!")
  end
  return file
end

function utils.read_whole_file(file)
  return file:read("*a")
end

function utils.close_file(file)
  io.close(file)
end

function utils.clear_log()
  local f = io.open("log.txt", "w")
  f.write(f, os.date("Log start at %c \n"))
  io.close(f)
end

function utils.log(branch, t)
  local f = io.open("log.txt", "a")
  local s = os.date("[%c]") .. branch .. ": " .. t .. "\n"
  f.write(f, s)
  io.close(f)
end

--@keep-select
function utils.place_block_by_name(name)
    local prev_select = robot.select()
    local num = chest_working.find_slot_by_name(name)
    utils.log("chest-debug", num)
    robot.select(num)
    robot.place(nil, true)
    robot.select(prev_select)
end

function utils.equip_tool_by_name(name)
  local prev_select = robot.select()
  local num = chest_working.find_slot_by_name(nil)
  robot.select(num)
  inv_cont.equip()
  local name_slot, _, _ = chest_working.inspect_slot(num)
  if (name_slot == name) then
    inv_cont.equip() --if already have such instrument equipped
  else
    num = chest_working.find_slot_by_name(name)
    if (num ~= nil) then
      robot.select(num)
      inv_cont.equip()
    else
      local success = chest_working.take_from_chest_and_return(name, 1)
      if (success == false) then
        utils.terminate_algo("Can't find/craft tool needed!") 
      end
      num = chest_working.find_slot_by_name(name)
      robot.select(num)
      inv_cont.equip()
    end
  end
  robot.select(prev_select)
end

function utils.deep_copy(t) --doesn't deal with metatables and stuff, just field-by-field copy
  local res = nil
  if (type(t) == 'table') then
    res = {}
    for key, val in pairs(t) do
      res[utils.deep_copy(key)] = utils.deep_copy(val)
    end
  else
    res = t
  end
  return res
end

function utils.bool_to_int(val)
  if (val) then return 1 else return 0 end
end

function utils.min(a, b)
  if (a < b) then return a else return b end
end

--END OF UTILS
--CRAFTING!


craft_work.recipe_table = {}

function craft_work.reload_recipe_table()
  craft_work.recipe_table = {}
  local recipe_file = utils.file_open_read("recipes.txt", "{}") 
  craft_work.recipe_table = serialization.unserialize(utils.read_whole_file(recipe_file))
  utils.log("craft_work", "Reloaded recipe table!")
  utils.close_file(recipe_file)
end

function craft_work.save_recipe_table()
  local recipe_file = utils.file_open_write("recipes.txt")
  recipe_file.write(recipe_file, serialization.serialize(craft_work.recipe_table))
  utils.close_file(recipe_file)
  utils.log("craft_work", "Saved recipe table!")
end

function craft_work.get_recipe(name)
  --ToDo make recipe priority list!
  for ind, recipe in ipairs(craft_work.recipe_table) do
    for item, amount in pairs(recipe["output"]) do
      if (item == name) then
        utils.log("craft_work", "Recipe found for name" .. name)
        if (recipe["ingredients"]["recipe_string"] ~= nil) then
          local tmp = {}
          for i = 1, 9 do
            local sym = string.sub(recipe["ingredients"]["recipe_string"], i, i)
            table.insert(tmp, {
                ["id"] = recipe["ingredients"]["short_names"][sym], 
                ["amount"] = 1,
                ["consumable"] = "yes"
                })
          end
          craft_work.recipe_table[ind]["ingredients"] = tmp
        end
        utils.log("recipe_processing", "After processing recipe is " .. serialization.serialize(recipe)) 
        return craft_work.recipe_table[ind]
      end
    end
  end
  utils.log("craft_work", "Recipe wasn't found for name" .. name)
end

--recipe structure:
--ingredients(in needed order)
----ingredient ID
----amount
----consumable
--machine
----name
----tier
----does machine needs to be reinstalled(when has some unconsumed ingredient)
----duration
--output(s)
----item
----amount


function craft_work.get_recipe_ingredients_table(name, amount)
  utils.log("get_reipe_ingredients_table", "called with name = " .. name .. " and amount = " .. amount)
  local recipe = craft_work.get_recipe(name)
  if (recipe == nil) then return nil end
  local out_am = recipe["output"][name]
  amount = amount / out_am + utils.bool_to_int(amount % out_am > 0)
  local ingredients = recipe["ingredients"] 
  local res = {}                  
  for _, val in ipairs(ingredients) do
    if (val["consumable"] == "no") then --ToDo check existance
      res[val["id"]] = (res[val["id"]] or 0) + 1
    else
      res[val["id"]] = (res[val["id"]] or 0) + amount
    end
  end
  return res, amount
end

function craft_work.build_craft_tree(name, amount, can_search_in_chests, success_table, fail_table, skip_store)
  utils.log("build_craft_tree", "Called with name = " .. name .. " and amount = " .. amount)
  if (can_search_in_chests) then
    local am = chest_working.calc_in_all_chests_by_name(name)
    local k = utils.min(am, amount)
    --chest_working.transfer_to_temporary_chests(name, k)
    chest_working.get_item_in_chests_by_name({[name] = k})
    amount = amount - k
  end
  local can_build = true
  if (amount > 0) then
    local t, left = craft_work.get_recipe_ingredients_table(name, amount) --now amount == how much times recipe should be crafted
    amount = left
    if (t == nil) then
      fail_table = fail_table or {}
      fail_table[name] = (fail_table[name] or 0) + amount
      return false, fail_table
    end
    table.insert(success_table, 1, {["name"] = name, ["amount"] = amount, ["recipe"] = craft_work.get_recipe(name)}) 
    for key, val in pairs(t) do
      local success, res_table = craft_work.build_craft_tree(key, val, true, success_table, fail_table) 
      if (success == false) then
        can_build = false
        fail_table  = res_table
      else
        success_table = res_table
      end
    end
  end
  if ((skip_store or false) == true) then
    movement.remember_my_position()
    movement.go_to_pos(movement.temp_chest_pos)
    chest_working.store_all_items()
    movement.restore_my_position()
  end
  if can_build == true then
    return true, success_table
  else
    return false, fail_table
  end
end

function craft_work.setup_crafting_table(recipe)
  local inv_size = robot.inventorySize() - chest_working.reserved_slots
  chest_working.clear_slots({1, 2, 3, 5, 6, 7, 9, 10, 11})
  for ind, i in ipairs({1, 2, 3, 5, 6, 7, 9, 10, 11}) do
    local success = false
    for j = 1, inv_size do
      if (j >= 12 or (j % 4 == 0)) then
        local name, _, _ = chest_working.inspect_slot(j)
        if (name == recipe["ingredients"][ind]["id"]) then
          robot.select(j)
          robot.transferTo(i, 1)
          success = true
          break
        end
      end
    end
    if (success == false) then
      utils.terminate_algo("couldn't set up crafting table!")
    end
  end
end

function craft_work.craft_recipe_prepared(recipe_data)
  movement.remember_my_position()
  local recipe = recipe_data["recipe"]
  if (recipe["machine"] == nil) then
    local max_am = 1
    for key, val in pairs(recipe["output"]) do
      if (val > max_am) then max_am = val end
    end
    local amount = recipe_data["amount"] * max_am
    while (amount > 0) do
      craft_work.setup_crafting_table(recipe) 
      local k = utils.min(amount, 64 - 64 % max_am)
      crafting.craft(k) 
      amount = amount - k
    end
    return true
  end
  if (recipe["machine"]["needs_reinstall"] == true) then
    machines.go_and_reinstall_machine(recipe["machine"]["name"], recipe["machine"]["tier"])
  end
  movement.go_to_pos(movement.common_chest_pos)
  chest_working.store_all_items()
  local pos = machines.search_machine_by_name_and_tier(recipe["machine"]["name"], recipe["machine"]["tier"])
  local ingredients_table = craft_work.get_recipe_ingredients_table(recipe_data["name"], recipe_data["amount"])
  robot.select(1)
  chest_working.get_item_in_chests_by_name(ingredients_table, true) 
  movement.go_to_pos(pos)
  movement.move_up()
  movement.move_up()  --depend ASSUMING "large-input" systems with external chests for each machine
  if (recipe_data["amount"] < 3) then
    for i = 1, recipe_data["amount"] do
      machines.fill_in_ingredients(recipe["ingredients"], i == 1)
      --machines.get_machine_output()
    end
  else
    machines.fill_in_ingredients(recipe["ingredients"], true)
    machines.fill_in_ingredients(recipe["ingredients"], false)
    movement.move_up()
    chest_working.store_all_items()
  end
  os.sleep(recipe["duration"] * recipe["amount"] + chest_working.time_to_reach_chest)
  movement.go_to_pos(movement.temp_chest_pos)
  chest_working.store_all_items()
  movement.restore_my_position()
end

--@pos-safe
function craft_work.craft_items(name, amount)
  craft_work.reload_recipe_table()
  movement.remember_my_position()  
  
  movement.go_to_pos(movement.common_chest_pos)
  
  local success, craft_list = craft_work.build_craft_tree(name, amount, false, {}, {})
  if (success == false) then
    print("Robot requires additional stuff to continue working!\n")
    chest_working.clear_temporary_chests()
    --ToDo log stuff
    for key, val in pairs(craft_list) do
      print(key, ": ", val)
    end
    utils.terminate_algo()
  else
    for _, val in ipairs(craft_list) do
      craft_work.craft_recipe_prepared(val)
    end
  end
  movement.restore_my_position()
end


--END OF CRAFTING
local function kill_entity()
--looks like we always need to reserve one slot for the sword
--ToDo implement sword stuff
end



--@keep_selected
local function lookaround_inspect_block()
  local prev_selected = robot.select()
  local num = chest_working.find_slot_by_name(nil)
  robot.select(num)
  local success = machines.harvest_mechanism() --ToDo make equip_tool_by_name keep inventory state
  if (success == false) then
    robot.select(prev_selected)
    return false
  end
  robot.select(num) --ToDo CHECK THAT INVENTORY WAS NOT CHANGED WHILE POSSIBLY GOING FOR NEW WRENCH!!!!!
  local name, _, _ = chest_working.inspect_slot(num)
  robot.place(nil, true) --depend TEST THIS SHIT
  machines.add_machine_by_name(name)
  robot.select(prev_selected)
  return true
end


local function startup_inventory() --ToDo add liquids 
  movement.remember_my_position()
  movement.go_to_zero() 
  movement.move_back(15)
  movement.rotate_back()
  movement.common_chest_pos = movement.get_current_pos()
  movement.move_left(2)
  movement.temp_chest_pos = movement.get_current_pos()
  movement.move_right(2)
  chest_working.store_all_items()
  movement.restore_my_position()
end

--depend - deal with local in all functions

local function startup_lookaround()
  algo_state = "lookaround"
  startup_inventory() 
  movement.move_forward(15)
  local k = movement.move_left(15)
  for _ = 1, k + 15 do
    local success = true
    for j = 1, 15 do
      lookaround_inspect_block()
      success = movement.move_up()
      if (success == false) then break end
    end
    movement.restore_y_coord()
    local nv, _ = movement.move_right()
    val = nv
    if (val == 0) then break end
  end
  movement.go_to_zero()
end

function movement_test()
  movement.move_left()
  movement.move_forward(4)
  movement.move_right(4)
  movement.move_back(2)
  movement.move_up(2)
  movement.move_left(1)
  movement.remember_my_position()
  movement.go_to_zero()
  movement.move_back(5)
  movement.restore_my_position()
end

function chest_test()
  startup_lookaround()
  for _, machine in pairs(machines.machines) do
    print(machine["machine"], machine["tier"])
  end
end

function add_recipe(inputs, machine, output)
  craft_work.reload_recipe_table()
  table.insert(craft_work.recipe_table, {["ingredients"] = inputs, ["machine"] = machine, ["output"] = output})
  craft_work.save_recipe_table()
end

function test_add_recipe()
  --[[add_recipe({
      {
      ["id"] = "Железный слиток",
      ["amount"] = 1,
      ["consumable"] = "yes"
      }
    }, {
    ["name"] = "Lathe",
    ["tier"] = 2,
    ["needs_reinstall"] = false,
    ["duration"] = 400 --ToDo idk the correct value
    }, {
      ["Iron Rod"] = 1,
      ["Small Pile of Iron Dust"] = 2
    })--]]
  add_recipe({
      ["short_names"] = {
        ["C"] = "Coal Dust",
        ["S"] = "Кремень"
      }, 
      ["recipe_string"] = "CCCCSCCCC"
    }, 
    nil,
    {
      ["Угольный шарик"] = 1
    })
  add_recipe({
      {
      ["id"] = "Угольный шарик",
      ["amount"] = 1,
      ["consumable"] = "yes"
      }
    }, {
    ["name"] = "Compressor",
    ["tier"] = 2,
    ["needs_reinstall"] = false,
    ["duration"] = 20 --ToDo idk the correct value
    }, {
      ["Сжатый угольный шарик"] = 1
    })
  add_recipe({
      ["short_names"] = {
        ["C"] = "Сжатый угольный шарик",
        ["S"] = "Обсидиан"
      }, 
      ["recipe_string"] = "CCCCSCCCC"
    }, 
    nil,
    {
      ["Угольная глыба"] = 1
    })
  add_recipe({
      {
      ["id"] = "Угольная глыба",
      ["amount"] = 1,
      ["consumable"] = "yes"
      }
    }, {
    ["name"] = "Compressor",
    ["tier"] = 2,
    ["needs_reinstall"] = false, 
    ["duration"] = 20 --ToDo idk the correct value
    }, {
      ["Промышленный алмаз"] = 1
    })
end

utils.clear_log()
--test_add_recipe()
startup_inventory()
--chest_working.get_item_in_chests_by_name({["Камень"] = 100, ["Iron Rod"] = 2})

--startup_lookaround()

craft_work.craft_items("Угольный шарик", 1)

print(craft_work.recipe_table)
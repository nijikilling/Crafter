local M = {}

local movement = require("movement")
local utils = require("utils")
local chest_working = require("chest_working")
local machines = require("machines")

local serialization = require("serialization")
local robot = require("robot")

local recipe_table = {}

function M.reload_recipe_table()
	recipe_table = {}
	local recipe_file = utils.file_open_read("recipes.txt", "{}") 
	recipe_table = serialization.deserialize(utils.read_whole_file(recipe_file))
	utils.close_file(recipe_file)
end

function M.get_recipe(name)
	return M.recipe_table[name]
end

--recipe structure:
--ingredients(in needed order)
----ingredient ID
----unconsumable
--machine
--tier
--does machine needs to be reinstalled(when has some unconsumed ingredient)

function M.get_recipe_ingredients_table(name, amount)
	local recipe = M.get_recipe(name)
	local t = recipe["ingredients"] 
	local res = {}                  
	for _, val in ipairs(t) do
		if (val["consumable"] == true) then --ToDo check existance
			res[val["id"]] = res[val["id"]] + 1
		else
			res[val["id"]] = res[val["id"]] + amount
		end
	end
	return res
end

function M.build_craft_tree(name, amount, can_search_in_chests, success_table, fail_table)
	if (can_search_in_chests) then
		local am = chest_working.calc_in_all_chests_by_name(name)
		local k = min(am, amount)
		chest_working.transfer_to_temporary_chests(name, k)
		amount = amount - k
	end
	local can_build = true
	if (amount > 0) then
		local t = M.get_recipe_ingredients_table(name, amount) 
		if (t == nil) then
			fail_table = fail_table or {}
			fail_table[name] = fail_table[name] + amount
			return false, fail_table
		end
		table.insert(success_table, 1, {["name"] = name, ["amount"] = amount, ["recipe"] = M.get_recipe(name)}) 
		for key, val in pairs(t) do
			local success, res_table = M.build_craft_tree(key, val, true, success_table, fail_table) 
			if (success == false) then
				can_build = false
				fail_table  = res_table
			else
				success_table = res_table
			end
		end
	end
	return can_build
end

function M.craft_recipe_prepared(recipe_data)
	movement.remember_my_position()
	local recipe = recipe_data["recipe"]
	if (recipe["machine_needs_reinstall"] == true) then
		machines.go_and_reinstall_machine(recipe["machine"], recipe["tier"])
	end
	movement.go_to_pos(movement.common_chest_pos)
	chest_working.store_all_items()
	local pos = machines.search_machine_by_name_and_tier(recipe["name"], recipe["tier"])
	local ingredients_table = M.get_recipe_ingredients_table(recipe_data["name"], recipe_data["amount"])
	robot.select(1)
	for key, val in pairs(ingredients_table) do
		chest_working.get_item_in_chest_by_name(key, val, true) 
	end
	movement.go_to_pos(pos)
	for i = 1, recipe_data["amount"] do
		machines.fill_in_ingredients(recipe["ingredients"], i == 1)
		os.sleep(recipe["duration"])
		machines.get_machine_output()
	end
	movement.go_to_pos(movement.temp_chest_pos)
	chest_working.store_all_items()
	movement.restore_my_position()
end

--@pos-safe
function M.craft_items(name, amount)
	M.reload_recipe_table()
	movement.remember_my_position()	
	
	movement.go_to_pos(movement.common_chest_pos)
	
	local success, craft_list = M.build_craft_tree(name, amount, false, {}, {})
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
			M.craft_recipe_prepared(val)
		end
	end
	movement.restore_my_position()
end

return M
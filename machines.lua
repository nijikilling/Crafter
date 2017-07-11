local M = {}

local inv_cont = require("inventory_controll")
local robot = require("robot")
local utils = require("utils")
local sides = require("sides")

local chest_working = require("chest_working")
local movement = require("movement")

M.machines = {}

function M.parse_machine_name(name)
  --depend
end

function M.add_machine_by_name(name)
	local voltage_tier, raw_name = M.parse_machine_name(name) --depend
	local t = {["tier"]:voltage_tier, ["machine"]:raw_name, ["c_x"]:cur_x, ["c_y"]:cur_y, ["c_z"]:cur_z, ["orientation"]:current_direction}
	table.insert(M.machines, t)
end

function M.fill_in_by_name(name, amount)
	while (amount > 0) do
		local last_amount = amount
		local p = chest_working.find_slot_by_name(name)
		local sz = inv_cont.getStackInInternalSlot(p)["size"]
		local k = min(sz, amount)
		robot.select(p)
		robot.drop(k)
		amount -= k
		if (amount == last_amount) do
			utils.terminate_algo("Looks like either some ingredients were removed, or robot has too small inventory!")
		end
	end
	return true
end

function M.fill_in_ingredients(recipe_ingredients, first_time)
	for i, ingredient in pairs(recipe_ingredients) do
		if ((ingredient["consumable"] == "no" and first_time) or ingredient["consumable"] == "yes") then
			M.find_in_by_name(ingredient["id"])
		end
	end
end

function M.get_machine_output()
	for i = 1, 4 do   --ToDo for processing-type recipes this should be configured, because suck() takes only one slot of output. 
		robot.suck()
	end
end

function M.search_machine_by_name_and_tier(name, tier)
	for i, machine in ipairs(M.machines) do
		if (name == machine["name"] and tier <= machine["tier"]) then
			return machine
		end
	end
	utils.terminate_algo("failed to find mechanism needed")
end

--@pos-safe
function M.go_and_reinstall_machine(pos)
	movement.remember_my_position()
	movement.go_to_pos(pos)
	equip_tool_by_name(wrench_name) --ToDo make constant or enum
	pos = chest_working.find_slot_by_name(nil)
	robot.select(pos)
	M.harvest_mechanism()
	robot.place(sides.front, true)
	movement.restore_my_position()
end

function M.harvest_mechanism()
	equip_tool_by_name(wrench_name)
	local success = robot.swing(sides.front)
	if (success) then robot.suck() end
	return success
end

return M
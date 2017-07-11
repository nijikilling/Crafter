local robot = require("robot")
local sides = require("sides")
local component = require("component")
local serialization = require("serialization")
local movement = require("movement")

local inv_cont = component.inventory_controller
local tank_cont = component.tank_controller

local movement = require("movement")
local chest_working = require("chest_working")
local machines = require("machines")
local utils = require("utils")
local crafting = require("crafting")

local gregtech_machine_name = "gregtech:gt.blockmachines"

local algo_state = "off"

function kill_entity()
--looks like we always need to reserve one slot for the sword
--ToDo implement sword stuff
end

function equip_tool_by_name(name)
	local num = chest_working.find_slot_by_name(nil)
	robot.select(num)
	robot.equip()
	local name_slot, string_id, tag = inspect_slot(num)
	if (name_slot == name) then
		robot.equip()
	else
		num = chest_working.find_slot_by_name(name)
		if (num ~= nil) then
			robot.select(num)
			robot.equip()
		else
			local success = chest_working.take_from_chest_and_return(name, 1)
			if (!success) then
				utils.terminate_algo("Can't find/craft tool needed!") 
			end
			num = chest_working.find_slot_by_name(name)
			robot.select(num)
			robot.equip()
		end
		
	end

end

local function lookaround_inspect_block()
	local num = chest_working.find_slot_by_name(nil)
	robot.select(num)
	local success = machines.harvest_mechanism() --ToDo make equip_tool_by_name keep inventory state
	if (success == false) then
		return false
	end
	robot.select(num) --ToDo CHECK THAT INVENTORY WAS NOT CHANGED WHILE POSSIBLY GOING FOR NEW WRENCH!!!!!
	local name, string_id, tag = inspect_slot(num)
	robot.place(sides.front, true) --depend TEST THIS SHIT
	machines.add_machine_by_name(name)
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
	movement.store_all_items()
	movement.restore_my_position()
end

--depend - deal with local in all functions

local function startup_lookaround()
	algo_state = "lookaround"
	startup_inventory() 
	
	local k = movement.move_left(15)
	for i = 1, k + 15 do
		local success, val = robot.detect()
		if (success == false) then break end
		while (success == true) do
			lookaround_inspect_block()
			movement.move_up()
			success, val = robot.detect()
		end
		movement.reset_y_coord()
		local nv, reason = movement.move_right()
    val = nv
		if (val == 0) then break end
	end
	movement.move_to_zero()
end




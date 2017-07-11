local M = {}

local inv_cont = require("inventory_controller")
local sides = require("sides")
local robot = require("robot")

local movement = require("movement")

local reserved_slots = 1


M.chest_name = "Сундук"
M.wrench_name = "Wrench"

function M.find_in_chest_by_name(name, amount, lootAll)
	local n = inv_cont.getInventorySize(sides.front)
	lootAll = lootAll or false
	if (lootAll ~= false) then
		amount = 100000 --workaround for 
	end
	for i = 1, n do
		local info = inv_cont.getStackInSlot(sides.front, i)
		if (info ~= nil) then
			local pos = nil
			if (lootAll) then
				pos = true
			else
				pos = string.find(string.lower(name), string.lower(info["label"]), 1, true) --depend better substring
			end
			if (pos ~= nil) then 
				local am = info["size"]
				inv_cont.suckFromSlot(sides.front, i, amount)
				local new_info = inv_cont.getStackInSlot(sides.front, i)
				local new_am = new_info["size"]
				amount = amount - (am - new_am)
			end
		end
		if (amount <= 0) then 
			return true, 0
		end
	end
	return false, amount
end

function M.have_adjanced_inventory()
	local n = inv_cont.getInventorySize(sides.front)
	if (n == nil or n == 0) then return false end
	return true
end

function M.calc_in_all_chests_by_name(name)
	local n = inv_cont.getInventorySize(sides.front)
	local am = 0
	while (M.have_adjanced_inventory()) do
		for i = 1, n do
			local info = inv_cont.getStackInSlot(sides.front, i)
			if (info ~= nil) then
				local pos = string.find(string.lower(name), string.lower(info["label"]), 1, true)
				if (pos ~= nil) then
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
function M.get_item_in_chest_by_name(name, amount, temp)
	movement.remember_my_position()
	if (temp == nil or temp == false) then
		movement.go_to_pos(movement.common_chest_pos)
	else
		movement.go_to_pos(movement.temp_chest_pos)
	end
	while (M.have_adjanced_inventory() and amount > 0) do
		local _, left = M.find_in_chest_by_name(name, amount)
		amount = left
		movement.move_up()
	end
	movement.restore_y_coord() 
	if (amount > 0) then
		local _, left, needed_parts = craft_items(name, amount) --depend only can be called for crafting tools
    amount = left
		if (amount > 0) then
			terminate_algo("can't find or craft needed amount of stuff")
			--ToDo log needed stuff
		end
	end
	movement.restore_my_position()
	return true, 0 
end

function M.find_slot_by_name(name)
	local size = robot.inventorySize() - reserved_slots
	for i = 1, size do
		local info = inv_cont.getStackInInternalSlot(i)
		if (info ~= nil) then
			if (info.name == name) then --wanna IC2 compatibility
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

function M.store_all_items()
	local internal_inv_size = robot.inventorySize() - reserved_slots
	local index = 1
	while (index <= internal_inv_size) do
		if (M.have_adjanced_inventory() == false) then
			craft_items(M.chest_name, 1) 
			place_block_by_name(M.chest_name)
		end
		local has_place = true
		while (index <= internal_inv_size and has_place) do
			robot.select(index)
			robot.drop()
			has_place = robot.count() == 0
			if (has_place) then index += 1 end
		end
		if (index <= internal_inv_size) then
			movement.move_up()
		end
	end
	return true
end

function M.transfer_to_temporary_chests(name, amount) 
	movement.remember_my_position()
	movement.go_to_pos(movement.common_chest_pos)
	local last_amount = 0
	while (last_amount ~= amount) do
		last_amount = amount
		local success, left = M.get_item_in_chest_by_name(name, amount) --pos-safe
    amount = left
		if (amount ~= last_amount) then
			movement.go_to_pos(movement.temp_chest_pos)
			M.store_all_items()
			movement.go_to_pos(movement.common_chest_pos)
		end
	end
	movement.restore_my_position()
end

function M.inventory_nonempty()
	local n = robot.inventorySize() - reserved_slots
	for i = 1, n do
		local info = inv_cont.getStackInInternalSlot(i)
		if (info ~= nil) then return true end
	end
	return false
end

function M.clear_temporary_chests()
	movement.remember_my_position()
	local robot_loots_something = true
	while(robot_loots_something == true) do
		movement.go_to_pos(movement.temp_chest_pos)
		while(M.have_adjanced_inventory()) do
			M.find_in_chest_by_name(" ", -1, true) --loot all from chest 
			movement.move_up()
		end
		robot_loots_something = M.inventory_nonempty()
		movement.go_to_pos(movement.common_chest_pos)
		M.store_all_items()
	end
  --ToDo return sth
end

function M.take_from_chest_and_return(name, amount)
	movement.remember_my_position() 
	movement.go_to_pos(movement.common_chest_pos) 
	M.get_item_in_chest_by_name(name, amount)
	movement.restore_my_position()
end

return M
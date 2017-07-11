--module with lots of mowement stuff!
local M = {}

local robot = require("robot")

local directions = {{0, 1}, {-1, 0}, {0, -1}, {1, 0}}
local current_direction = 0
local cur_x = 0
local cur_y = 0
local cur_z = 0
local position_stack = {}
M.common_chest_pos = nil
M.temp_chest_pos = nil

function M.move_with_errors_handling(n, move_function)
  
--does:    tries to apply move_function n times, handling some errors(i.m. trying to kill entities on the way, repeating action)
--returns: amount of steps done
	n = n or 1
  print(n)
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
	return n, "success"
end

function M.alg_modulo(n, mod)
	return (n + mod) % mod
end

function M.update_relative_position(n, delta)
  print(n, delta)
  print(M.alg_modulo(current_direction + delta, 4) + 1)
  print(directions[M.alg_modulo(current_direction + delta, 4) + 1][1])
	cur_x = cur_x + directions[M.alg_modulo(current_direction + delta, 4) + 1][1] * n
	cur_z = cur_z + directions[M.alg_modulo(current_direction + delta, 4) + 1][2] * n
end

function M.move_forward(n)
	local res, reason = M.move_with_errors_handling(n, robot.forward)
	M.update_relative_position(res, 0)
	return res, reason
end

function M.move_back(n)
	local res, reason = M.move_with_errors_handling(n, robot.back)
	M.update_relative_position(res, 2)
	return res, reason
end

function M.move_up(n)
	local res, reason = M.move_with_errors_handling(n, robot.up)
	cur_y = cur_y + res
	return res, reason
end

function M.move_down(n)
	local res, reason M.move_with_errors_handling(n, robot.down)
	cur_y = cur_y - res
	return res, reason
end

function M.rotate_left()
	robot.turnLeft()
	current_direction = M.alg_modulo(current_direction + 1, 4)
end

function M.rotate_right()
	robot.turnRight()
	current_direction = M.alg_modulo(current_direction - 1, 4)
end

function M.rotate_back()
  --Rotates back
	robot.turnLeft()
	robot.turnLeft()
	current_direction = M.alg_modulo(current_direction + 2, 4)
end

function M.move_left(n)
	M.rotate_left()
	local res, reason = M.move_forward(n)
	M.rotate_right()
	return res, reason
end

function M.move_right(n)
	M.rotate_right()
	local res, reason = M.move_forward(n)
	M.rotate_left()
	return res, reason
end

function M.go_to_pos(pos)
	while current_direction ~= 0 do M.rotate_left() end
	local delta_x = pos["x"] - cur_x
	local delta_y = pos["y"] - cur_y
	local delta_z = pos["z"] - cur_z
	local iter = 0
	while (delta_x ~= 0 or delta_y ~= 0 or delta_z ~= 0) do
		if (delta_x > 0) then delta_x = delta_x - M.move_right(delta_x) end
		if (delta_x < 0) then delta_x = delta_x + M.move_left(delta_x) end
		
		if (delta_y > 0) then delta_y = delta_y - M.move_up(delta_y) end
		if (delta_y < 0) then delta_y = delta_y + M.move_down(delta_y) end
		
		if (delta_z > 0) then delta_z = delta_z - M.move_forward(delta_z) end
		if (delta_z < 0) then delta_z = delta_z + M.move_back(delta_z) end
		
		iter = iter + 1
		if (iter >= 50) then
			return false, "failed, unknown reasons" --ToDo log this shit
		end
	end
	while current_direction ~= pos["orientation"] do M.rotate_left() end
	return true
end

function M.remember_my_position()
	table.insert(position_stack, {["x"]=cur_x, ["y"]=cur_y, ["z"]=cur_z, ["orientation"]=current_direction})
end

function M.go_to_zero()
	return M.go_to_pos({["x"]=0, ["y"]=0, ["z"]=0, ["orientation"]=0})
end

function M.restore_my_position()
	return M.go_to_pos(table.remove(position_stack))
end

function M.restore_y_coord()
  return M.move_down(cur_y)
end

return M

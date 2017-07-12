local M = {}

local movement = require("movement")

local working_folder = "~\\crafter"

function M.terminate_algo(reason)
	movement.go_to_zero()
	print(reason)
	os.exit(-1)
end

function M.file_open_read(name, default)
	name = working_folder + "\\" + name
	local file = io.open(name, "r")
	if (file == nil) then
		file = io.open(name, "w")
		io.write(file, default)
		io.close(file)
	end
	file = io.open(name, "r")
	if(file == nil) then
		M.terminate_algo("can't create file!")
	end
	return file
end

function M.read_whole_file(file)
	return file:read("*a")
end

function M.close_file(file)
	file.close()
end

function M.clear_log()
  local f = io.open("log.txt", "w")
  f.write(f, os.date("Log start at %c \n"))
  io.close(f)
end

function M.log(branch, t)
  local f = io.open("log.txt", "a")
  local s = os.date("[%c]") .. branch .. ": " .. t .. "\n"
  f.write(f, s)
  io.close(f)
end

return M
local test_utils = {}

function test_utils.deep_copy(t) --doesn't deal with metatables and stuff, just field-by-field copy
  local res = nil
  if (type(t) == 'table') then
    res = {}
    for key, val in pairs(t) do
      res[test_utils.deep_copy(key)] = test_utils.deep_copy(val)
    end
    setmetatable(res, test_utils.deep_copy(getmetatable(t)))
  else
    res = t
  end
  return res
end

function test_utils.raise_error(message)
  io.stderr:write(message)
  error(message)
  os.exit(1)
end

function test_utils.file_open_read(name, default)
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

function test_utils.file_open_write(name)
  local file = io.open(name, "w")
  if (file == nil) then
    utils.terminate_algo("can't create file!")
  end
  return file
end

function test_utils.read_whole_file(file)
  return file:read("*a")
end

function test_utils.close_file(file)
  io.close(file)
end

return test_utils
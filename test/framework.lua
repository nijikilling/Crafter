local framework = {}

function framework.run_all_test_suits()
  --depend
end

function framework.run_test(test)
  test()
  framework.unload_modules()
end

function framework.unload_modules()
  local names = {"component", "crafting", "inventory", "inventory_controller", "robot", "serialization", "sides", "test_utils", "world_mock"}
  for _, pack_name in ipairs(names) do
    package.loaded[pack_name] = nil
  end
end

function framework.equal_objects()
  
end

function framework.deep_copy(t) --doesn't deal with metatables and stuff, just field-by-field copy
  local res = nil
  if (type(t) == 'table') then
    res = {}
    for key, val in pairs(t) do
      res[framework.deep_copy(key)] = framework.deep_copy(val)
    end
    setmetatable(res, framework.deep_copy(getmetatable(t)))
  else
    res = t
  end
  return res
end

function framework.equal_objects(a, b)
  if (type(a) ~= type(b)) then return false end
  if (type(a) ~= "table") then return a == b end
  for key, val in pairs(a) do
    if (framework.equal_objects(val, b[key]) == false) then return false end
  end
  return true
end

return framework
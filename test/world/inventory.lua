local inventory = {}

local test_utils = require("test_utils") --ToDo make fukken utils class

inventory.c_inv = { }
inventory.c_inv.mt = {}

inventory.c_inv.mt.__eq = function (a, b)
  if (a:get_size() ~= b:get_size()) then 
    return false
  end
  for i = 1, a:get_size() do
    if (a:get_slot(i) ~= b:get_slot(i)) then
      return false
    end
  end
  return true
end

inventory.c_inv.mt.__metatable = "not today"

inventory.c_inv.mt.__index = function (table, key)
  local res = rawget(inventory.c_inv, key)
  if (res == nil) then 
    test_utils.raise_error("nil called in inventory!") 
  end
  return res
end

function inventory.c_inv.new(size)
  local new_inv = {n = size} 
  for i = 1, size do
    new_inv[i] = inventory.c_slot.new()
  end
  setmetatable(new_inv, inventory.c_inv.mt)
  return new_inv
end

function inventory.c_inv.get_size(inv)
  return inv["n"]
end

function inventory.c_inv.get_slot(inv, slot)
  if (slot < 1) or (slot > inv.n) then 
    test_utils.raise_error("slot in inventory was out of range!") 
  end
  return inv[slot]
end

function inventory.c_inv.get_count(inv, slot)
  return inv:get_slot(slot):count()
end

function inventory.c_inv.get_space(inv, slot)
  return inv:get_slot(slot):get_space()
  --ToDo make at least Buckets be not 64-stacked
end



function inventory.c_inv.receive(target_inv, slot_obj, count, from_pos)
  -- transfers up to [count] items from [from_inv]'s [slot] to [target_inv] 
  --[from_pos] is workaround for robot's selected slot mechanic - it actually stores items from it, not from 1th slot
  from_pos = from_pos or 1
  local am = math.min(count, slot_obj:get_count())
  local q = false
  if (am == 0) then return false end
  for ind = 1, target_inv:get_size() do
    local i = (ind + from_pos - 2) % target_inv:get_size() + 1 
    if (am == 0) then return true end
    if (target_inv:get_slot(i):get_id() == slot_obj:get_id()) then
      local k = math.min(target_inv:get_space(i), am)
      target_inv:get_slot(i):add(k)
      slot_obj:takeaway(k) --depend
      am = am - k
      q = true
    end
  end
  for ind = 1, target_inv:get_size() do
    local i = (ind + from_pos - 2) % target_inv:get_size() + 1
    if (am == 0) then return true end
    if (target_inv[i]:get_id() == nil) then
      target_inv:get_slot(i):add(am)
      target_inv:get_slot(i):set_id(slot_obj:get_id())
      slot_obj:takeaway(am)
      am = 0
      q = true
    end
  end
  return q
end

function inventory.c_inv.receive_inventory(target_inv, from_inv, from_pos)
  for i = 1, from_inv.n do 
    target_inv:receive(from_inv:get_slot(i), 64, from_pos)
  end
end


--==================
--=Here goes c_slot=
--==================


inventory.c_slot = { }
inventory.c_slot.mt = { }
inventory.c_slot.mt.__eq = function (a, b)
  if (a:get_id() ~= b:get_id()) then return false end
  if (a:get_count() ~= b:get_count()) then return false end
  return true
end

inventory.c_slot.mt.__metatable = "not today"

inventory.c_slot.mt.__index = function (table, key)
  local res = rawget(inventory.c_slot, key)
  if (res == nil) then 
    test_utils.raise_error("nil called in inventory! with key = " .. key) 
  end
  return res
end



function inventory.c_slot.new(slot_init_data)
  local val = slot_init_data or {}
  if (val["id"] ~= nil) then val["count"] = val["count"] or 1 end
  local res = {}
  res["id"] = val["id"]
  res["count"] = val["count"] or 0
  
  setmetatable(res, inventory.c_slot.mt)
  return res
end

function inventory.c_slot.get_space(slot_obj)
  return slot_obj:get_max_count() - slot_obj:get_count()
end

function inventory.c_slot.get_count(slot_obj)
  return slot_obj["count"]
end

function inventory.c_slot.get_max_count(slot_obj)
  return 64 --ToDo buckets
end

function inventory.c_slot.get_id(slot_obj)
  return rawget(slot_obj, "id")
end

function inventory.c_slot.set_slot(slot_obj, new_slot)
  slot_obj["id"] = new_slot["id"]
  slot_obj["count"] = new_slot["count"]
end


function inventory.c_slot.takeaway(slot_obj, count)
  slot_obj["count"] = slot_obj["count"] - count
  if (slot_obj["count"] == 0) then 
    slot_obj["count"] = 0
    slot_obj:clear_id()
  end
  if (slot_obj["count"] < 0) then
    test_utils.raise_error("trying to take away too much from slot!")
  end
end

function inventory.c_slot.add(slot_obj, count)
  slot_obj["count"] = slot_obj["count"] + count
  if (slot_obj:get_count() > slot_obj:get_max_count()) then
    test_utils.raise_error("trying to put too much to slot!")
  end
end

function inventory.c_slot.clear_id(slot_obj)
  slot_obj["id"] = nil
end

function inventory.c_slot.set_id(slot_obj, new_id)
  if (slot_obj:get_id() ~= nil) then test_utils.raise_error("non-empty id set") end
  slot_obj["id"] = new_id
end

function inventory.inv_link_update(link)
  local from = link.inv
  local to = link.out_inv
  for i = 1, from.n do
    to:receive(to, from[i], 64)
  end
end

function inventory.print_inventory(inv)
  print("Printing inventory at address: " .. inv)
  print("--inventory size: " .. inv.n)
  for i = 1, inv.n do
    if (inv[i].count > 0) then
      print("--" .. i .. "th slot - " .. (inv[i].label or "nil") .. ", count = " .. (inv[i].count or 0))
    end
  end
end

return inventory
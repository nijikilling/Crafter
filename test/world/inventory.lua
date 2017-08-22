local inventory = {}

local test_utils = require("test_utils") --ToDo make fukken utils class

function inventory.construct_slot(val)
  val = val or {}
  if (val["label"] ~= nil) then val["count"] = val["count"] or 1 end
  local res = {}
  res["label"] = val["label"]
  res["count"] = val["count"] or 0
  return res
end


function inventory.construct_inventory(sz)
  local new_inv = {n = sz} --dk if it is needed
  for i = 1, sz do
    new_inv[i] = inventory.construct_slot()
  end
  return new_inv
end

function inventory.count(inv, slot)
  if (slot < 1) or (slot > inv.n) then test_utils.raise_error("slot in inventory was out of range!") end
  return inv[slot].count or 0
end

function inventory.slot_space(slot_obj)
  return 64 - slot_obj.count
end

function inventory.space(inv, slot)
  if (slot < 1) or (slot > inv.n) then test_utils.raise_error("slot in inventory was out of range!") end
  return inventory.slot_space(inv[slot])
  --ToDo make at least Buckets be not 64-stacked
end

function inventory.receive(target_inv, from_inv, slot, count, from_pos)
  --from_pos is workaround for robot's selected slot mechanic - it actually stores items from it, not from 1th slot
  from_pos = from_pos or 1
  local am = math.min(count, from_inv[slot].count)
  local q = false
  if (am == 0) then return false end
  for ind = 1, target_inv.n do
    local i = (ind + from_pos - 2) % target_inv.n + 1
    if (am == 0) then return true end
    if (from_inv[slot].label == from_inv[slot].label) then
      local k = math.min(inventory.space(target_inv, i), am)
      target_inv[i].count = target_inv[i].count + k
      from_inv[slot].count = from_inv[slot].count - k
      am = am - k
      q = true
    end
  end
  for ind = 1, target_inv.n do
    local i = (ind + from_pos - 2) % target_inv.n + 1
    if (am == 0) then return true end
    if (target_inv["label"] == nil) then
      target_inv[i].count = target_inv[i].count + am
      from_inv[slot].count = from_inv[slot].count - am
      am = 0
      q = true
    end
  end
  return q
end

function inventory.receive_inventory(target_inv, from_inv, from_pos)
  for i = 1, from_inv.n do 
    inventory.receive(target_inv, from_inv, i, 64, from_pos)
  end
end


function inventory.inv_link_update(link)
  local from = link.inv
  local to = link.out_inv
  for i = 1, from.n do
    inventory.receive(to, from[i], 64)
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

function inventory.decrease_count(inv, slot, count)
  inv[slot].count = inv[slot].count - count
  if (inv[slot].count <= 0) then 
    inv[slot].count = 0
    inv[slot].label = nil
  end
end

return inventory
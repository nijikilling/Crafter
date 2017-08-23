local lunatest = package.loaded.lunatest

--package.path = package.path .. ';./test/?.lua' .. ';./test/world/?.lua' .. ';./world/?.lua' .. ';./lunatest/?.lua' .. ';./test/lunatest/?.lua'

local test_inventory = {}

function test_inventory.test_receive()
  local inventory = require("inventory")
  local inv = inventory.c_inv.new(64)
  
  inv:receive(inventory.c_slot.new({id="Stone", count=63}), 64, 15)
  inv:receive(inventory.c_slot.new({id="Bench", count=64}), 63, 14)
  inv:receive(inventory.c_slot.new({id="Bench", count=63}), 62, 14)
  
  lunatest.assert_true(inv:get_slot(14):get_id() == "Bench")
  lunatest.assert_true(inv:get_slot(14):get_count() == 64)
  
  lunatest.assert_true(inv:get_slot(15):get_id() == "Stone")
  lunatest.assert_true(inv:get_slot(15):get_count() == 63)
  
  lunatest.assert_true(inv:get_slot(16):get_id() == "Bench")
  lunatest.assert_true(inv:get_slot(16):get_count() == 61)
end

function test_inventory.test_full_receive()
  local inventory = require("inventory")
  local inv = inventory.c_inv.new(2)
  
  inv:receive(inventory.c_slot.new({id="Stone", count=63}), 64, 2)
  inv:receive(inventory.c_slot.new({id="Bench", count=64}), 63, 1)
  inv:receive(inventory.c_slot.new({id="Beans", count=63}), 62, 1)
  
  lunatest.assert_true(inv:get_slot(1):get_id() == "Bench")
  lunatest.assert_true(inv:get_slot(1):get_count() == 63)
  
  lunatest.assert_true(inv:get_slot(2):get_id() == "Stone")
  lunatest.assert_true(inv:get_slot(2):get_count() == 63)
  
  --lunatest.assert_true(inv:get_slot(3):get_id() == nil)
  --lunatest.assert_true(inv:get_slot(3):get_count() == 0)
end

function test_inventory.test_space_stuff()
  local inventory = require("inventory")
  local inv = inventory.c_inv.new(1)
  
  inv:receive(inventory.c_slot.new({id="Stone", count=63}), 64, 1)
  
  lunatest.assert_true(inv:get_slot(1):get_space() == 1)
  lunatest.assert_true(inv:get_slot(1):get_count() == 63)

end

function test_inventory.test_equality()
  local inventory = require("inventory")
  local a = inventory.c_inv.new(1)
  local b = inventory.c_inv.new(3)
  lunatest.assert_false(a == b)
  local c = inventory.c_inv.new(1)
  lunatest.assert_true(a == c)
  
  local d = inventory.c_inv.new(3)
  b:receive(inventory.c_slot.new({id="Stone", count=64}), 64, 1)
  d:receive(inventory.c_slot.new({id="Stone", count=64}), 64, 1)
  
  d:receive(inventory.c_slot.new({id="Stone", count=63}), 63, 1)
  b:receive(inventory.c_slot.new({id="Stone", count=63}), 63, 2)
  lunatest.assert_true(b == d)
end

function test_inventory.test_slot_give()
  local inventory = require("inventory")
  local slot_obj = inventory.c_slot.new({id="Stone", count=13})
  slot_obj:takeaway(13)
  lunatest.assert_true(slot_obj:get_id() == nil)
  lunatest.assert_true(slot_obj:get_count() == 0)
  
  slot_obj:set_id("Chain")
  slot_obj:add(64)
  lunatest.assert_true(slot_obj:get_count() == 64)
end

--test_inventory.test_equality()

return test_inventory
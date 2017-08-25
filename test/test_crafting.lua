local lunatest = package.loaded.lunatest

--package.path = package.path .. ';./test/?.lua' .. ';./test/world/?.lua' .. ';./world/?.lua' .. ';./lunatest/?.lua' .. ';./test/lunatest/?.lua'

local test_crafting = {}

function test_crafting.test_easy()
  package.loaded.robot = nil
  package.loaded.crafting = nil
  package.loaded.inventory = nil
  local crafting = require("crafting")
  local robot = require("robot")
  local inventory = require("inventory")
  local tmp_slot = inventory.c_slot.new({id = "Wood", count = 1})
  for _, i in ipairs({1, 2, 3, 5, 7, 9, 10, 11}) do
    robot.inv:get_slot(i):set_slot(tmp_slot)
  end
  robot.select(6)
  crafting.craft(1)
  lunatest.assert_true(robot.inv:get_slot(6):get_id() == "Chest")
  lunatest.assert_true(robot.inv:get_slot(6):get_count() == 1)
  for _, i in ipairs({1, 2, 3, 5, 7, 9, 10, 11}) do
    lunatest.assert_true(robot.inv:get_slot(i):get_count() == 0)
  end
end

function test_crafting.test_noninteger_craft_and_leftovers()
  package.loaded.robot = nil
  package.loaded.crafting = nil
  package.loaded.inventory = nil
  local crafting = require("crafting")
  local robot = require("robot")
  local inventory = require("inventory")
  robot.inv:get_slot(1):set_slot(inventory.c_slot.new({id="Wood", count=3}))
  robot.inv:get_slot(5):set_slot(inventory.c_slot.new({id="Wood", count=3}))
  robot.select(5)
  crafting.craft(3)
  
  lunatest.assert_true(robot.inv:get_slot(1):get_id() == "Wood")
  lunatest.assert_true(robot.inv:get_slot(1):get_count() == 2)
  
  lunatest.assert_true(robot.inv:get_slot(5):get_id() == "Wood")
  lunatest.assert_true(robot.inv:get_slot(5):get_count() == 2)
  
  lunatest.assert_true(robot.inv:get_slot(6):get_id() == "Stick")
  lunatest.assert_true(robot.inv:get_slot(6):get_count() == 2)
end

--test_crafting.test_noninteger_craft_and_leftovers()

return test_crafting
require "lunit"
module("testcase_inventory", lunit.testcase)

function test_receive()
  local inventory = require("inventory")
  local inv = inventory.construct_inventory(64)
  inventory.receive(inv, {{label="Stone", count=1}, n = 1}, 1, 15)
  inventory.receive(inv, {{label="Bench", count=63}, n = 1}, 1, 14)
  inventory.receive(inv, {{label="Bench", count=62}, n = 1}, 1, 14)
  assert_true(inv[14].label == "Bench")
  assert_true(inv[14].count == 64)
  assert_true(inv[15].label == "Stone")
  assert_true(inv[15].label == 1)
  assert_true(inv[16].label == "Bench")
  assert_true(inv[16].label == 61)
end
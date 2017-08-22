local lunatest = package.loaded.lunatest

local test_inventory = {}

function test_inventory.test_receive()
  local inventory = require("inventory")
  local inv = inventory.construct_inventory(64)
  inventory.receive(inv, {{label="Stone", count=1}, n = 1}, 1, 64, 15)
  inventory.receive(inv, {{label="Bench", count=64}, n = 1}, 1, 63, 14)
  inventory.receive(inv, {{label="Bench", count=63}, n = 1}, 1, 62, 14)
  lunatest.assert_true(inv[14].label == "Bench")
  lunatest.assert_true(inv[14].count == 64)
  lunatest.assert_true(inv[15].label == "Stone")
  lunatest.assert_true(inv[15].count == 1)
  lunatest.assert_true(inv[16].label == "Bench")
  lunatest.assert_true(inv[16].count == 61)
end

return test_inventory
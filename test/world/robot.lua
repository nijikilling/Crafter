local robot = {}

local test_utils = require("test_utils")
local world_mock = require("world_mock")
local inventory  = require("inventory")
local sides      = require("sides")

local robot_name = "Creatix"
local robot_level = 1.36
local robot_inv_size = 64
local robot_tool = inventory.c_slot.new({["label"] = "Wrench", ["count"] = 1})
local robot_tank_cnt = 1
local robot_dir = 1
local robot_pos = {x = 0, y = 0, z = 0}

robot.inv = inventory.c_inv.new(robot_inv_size) 

local directions = {{x = 1, y = 0, z = 0}, 
                    {x = 0, y = 0, z = -1}, 
                    {x = -1, y = 0, z = 0}, 
                    {x = 0, y = 0, z = 1}}

local direction_up   = {x = 0, y =  1, z = 0}
local direction_down = {x = 0, y = -1, z = 0}

local selected_slot = 1
local selected_tank = 1

function robot._add_coords(a, b)
    return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}
end

function robot._modulo(a, mod)
  return (a + mod) % mod
end

function robot.get_direction_by_side(side)
  if (side == sides.bottom) then return direction_down end
  if (side == sides.top)    then return direction_up end
  local local_dirs = {3, 1, 4, 2}
  if (side == sides.back)   then return directions[(local_dirs[1] + robot_dir - 2) % 4 + 1] end
  if (side == sides.front)  then return directions[(local_dirs[2] + robot_dir - 2) % 4 + 1] end
  if (side == sides.right)  then return directions[(local_dirs[3] + robot_dir - 2) % 4 + 1] end
  if (side == sides.left)   then return directions[(local_dirs[4] + robot_dir - 2) % 4 + 1] end
end

function robot.get_adjanced_pos(side)
  return robot._add_coords(robot.get_direction_by_side(side), robot_pos)
end

function robot.name()
  return robot._name
end

local function _detect(k) --ToDo add liquids, passable, replaceable
 if (k == nil) then return true, "air" end
 if (k.type == nil) then return true, "air" end
 if (k.type == "creature") then return false, "entity" end
 return false, "solid"
end

function robot.detect()
  local k = world_mock.get_object_by_pos(robot.get_adjanced_pos(sides.front))
  return _detect(k)
end

function robot.detectUp()
  local k = world_mock.get_object_by_pos(robot.get_adjanced_pos(sides.top))
  return _detect(k)
end

function robot.detectDown()
  local k = world_mock.get_object_by_pos(robot.get_adjanced_pos(sides.bottom))
  return _detect(k)
end

function robot.select(slot)
  if (slot == nil) then return selected_slot end
  if (slot > robot.inventorySize()) or (slot < 1) then test_utils.raise_error("robot slot out of range!") end
  selected_slot = slot
end

function robot.inventorySize()
  return robot.inv:get_size()
end

function robot.count(slot)
  return robot.inv:get_slot(slot):get_count() 
end

function robot.space(slot)
  return robot.inv:get_slot(slot):get_space()
end

function robot.transferTo(slot, count) --depend
  local cur = robot.select()
  if (cur == count) then return end
  if (robot.inv:get_slot(cur):get_count() == 0) or 
(robot.inv:get_slot(slot):get_count() == 0) then
    robot.inv:swap_slots(cur, slot)
    return true
  end
  if (robot.inv:get_slot(cur):get_count() <= count) then
    robot.inv:swap_slots(cur, slot)
    return true
  end
  test_utils.raise_error("transferTo tries partial transfer to nonempty slot!")
  return false
end

local function _drop(block, count)
  if (block == nil) then test_utils.raise_error("_drop tries to throw items out") end
  if (block.type == "creature") or (block.type == "tank") or (block.type == "solid") then
    test_utils.raise_error("_drop tries to throw items into " .. (block.type or "nil"))
  end
  local num = robot.select()
  local q = block.inv:receive(robot.inv:get_slot(num), count, 1) --ToDo hardcoded
  world_mock.update_inv_links()
  return q
end

function robot.drop(count)
  return _drop(world_mock.get_object_by_pos(robot.get_adjanced_pos(sides.front)), count)
end

function robot.dropUp(count)
  return _drop(world_mock.get_object_by_pos(robot.get_adjanced_pos(sides.top)), count)
end

function robot.dropDown(count)
  return _drop(world_mock.get_object_by_pos(robot.get_adjanced_pos(sides.bottom)), count)
end

function robot._place(block_pos, side, sneaky)
  local slot_obj = robot.inv:get_slot(robot.select()) --yes, we can use slot_obj here
  if (slot_obj.count == 0) then return false, "empty slot!" end
  local k = world_mock.get_object_by_pos(block_pos)
  if (k ~= nil) then return false, "attempt to place block not in the air but in " .. k.type end
  local res = world_mock.get_object_blueprint_by_name(slot_obj:get_id())
  res.pos = block_pos
  world_mock.add_object(res)
  slot_obj:takeaway(1)
  return true
end

function robot.place(side, sneaky)
  return robot._place(robot.get_adjanced_pos(sides.front), side, sneaky)
end

function robot.placeUp(side, sneaky)
  return robot._place(robot.get_adjanced_pos(sides.top), side, sneaky)
end

function robot.placeDown(side, sneaky)
  return robot._place(robot.get_adjanced_pos(sides.bottom), side, sneaky)
end

local function _swing(block, side, sneaky)
  if (block == nil) then return false end
  if (block.type == "machine") and (robot_tool.label == "Wrench") then
    robot.inv:receive_inventory(block.inv)
    robot.inv:receive_inventory(block.out_inv)
    world_mock.erase_block(block) 
    robot.inv:receive(inventory.c_slot.new(block), 1, 1) 
    return true, "block"
  end
  if (block.type == "creature") then
    block.hp = block.hp - 1
    if (block.hp <= 0) then
      world_mock.erase_block(block)
    end
    return true, "entity"
  end
end

function robot.swing(side, sneaky)
  return _swing(world_mock.get_object_by_pos(robot.get_adjanced_pos(sides.front)), side, sneaky)
end

function robot.swingUp(side, sneaky)
  return _swing(world_mock.get_object_by_pos(robot.get_adjanced_pos(sides.top)), side, sneaky)
end

function robot.swingDown(side, sneaky)
  return _swing(world_mock.get_object_by_pos(robot.get_adjanced_pos(sides.bottom)), side, sneaky)
end

local function _move(pos)
  local obj = world_mock.get_object_by_pos(pos)
  if (obj == nil) then return true end
  if (obj.type == "machine") or (obj.type == "solid") or (obj.type == "chest") or (obj.type == "tank") then
    return nil, "solid"
  end
  if (obj.type == "creature") then return nil, "entity" end
end

function robot.forward()
  return _move(robot.get_adjanced_pos(sides.front))
end

function robot.back()
  return _move(robot.get_adjanced_pos(sides.back))
end

function robot.up()
  return _move(robot.get_adjanced_pos(sides.top))
end

function robot.down()
  return _move(robot.get_adjanced_pos(sides.bottom))
end

function robot.turnLeft()
  robot_dir = robot._modulo(robot_dir + 1, 4)
end

function robot.turnRight()
  robot_dir = robot._modulo(robot_dir - 1, 4)
end

function robot.turnAround()
  robot_dir = robot._modulo(robot_dir + 2, 4)
end

function robot.level()
  return robot_level
end

--ToDo tanks

return robot
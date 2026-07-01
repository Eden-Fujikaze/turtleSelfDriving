local detector = peripheral.find("player_detector")
local TARGET_NAME = "Eden_Fujikaze"

local RANGE = 50
local MIN_RANGE = 6
local MIN_RANGE_RELEASE = 8
local MOVE_EPS = 0.3

-- redstone link faces
local FACE_BRAKE      = "left"
local FACE_REVERSE    = "right"   -- gearshift toggle (unused by this simplified logic, kept for future)
local FACE_LEFT_BOTH  = "top"
local FACE_RIGHT_BOTH = "bottom"
local FACE_FRONT      = "front"

-- turning vs driving hysteresis: wide gap so it doesn't flicker at the edge
local ENTER_TURN = 15   -- if facing error exceeds this while driving straight, start turning
local EXIT_TURN  = 5    -- once turning, must get within this to switch to driving straight

local TICK = 0.25

if not detector then error("no detector") end

local lastX, lastZ = nil, nil
local heading = 0
local tooClose = false
local state = "brake" -- "brake" | "turnLeft" | "turnRight" | "front"

local function normAngle(a)
  a = a % 360
  if a > 180 then a = a - 360 end
  return a
end

local function clearAll()
  redstone.setOutput(FACE_BRAKE, false)
  redstone.setOutput(FACE_LEFT_BOTH, false)
  redstone.setOutput(FACE_RIGHT_BOTH, false)
  redstone.setOutput(FACE_FRONT, false)
end

local function setState(newState)
  if newState == state then return end
  state = newState
  clearAll()
  if state == "brake" then
    redstone.setOutput(FACE_BRAKE, true)
  elseif state == "turnLeft" then
    redstone.setOutput(FACE_LEFT_BOTH, true)
  elseif state == "turnRight" then
    redstone.setOutput(FACE_RIGHT_BOTH, true)
  elseif state == "front" then
    redstone.setOutput(FACE_FRONT, true)
  end
end

while true do
  local myX, myY, myZ = gps.locate()

  if not myX then
    print("GPS fix failed, skipping this cycle")
  else
    -- heading estimate from GPS motion (only updates while actually moving,
    -- i.e. in "front" state — turning in place won't move X/Z much)
    if lastX then
      local mdx, mdz = myX - lastX, myZ - lastZ
      if math.sqrt(mdx * mdx + mdz * mdz) > MOVE_EPS then
        heading = normAngle(math.deg(math.atan2(mdz, mdx)))
      end
    end
    lastX, lastZ = myX, myZ

    local ok, playerPos = pcall(function() return detector.getPlayerPos(TARGET_NAME) end)

    if not ok or not playerPos then
      print("Could not get player position:", playerPos)
      setState("brake")
    else
      local dx = playerPos.x - myX
      local dz = playerPos.z - myZ
      local distance = math.sqrt(dx * dx + dz * dz)

      if tooClose then
        if distance > MIN_RANGE_RELEASE then tooClose = false end
      else
        if distance < MIN_RANGE then tooClose = true end
      end

      if distance > RANGE or tooClose then
        setState("brake")
      else
        local targetAngle = math.deg(math.atan2(dz, dx))
        local diff = normAngle(targetAngle - heading)

        print(string.format("dist=%.1f heading=%.1f diff=%.1f state=%s",
          distance, heading, diff, state))

        if state == "front" then
          -- only break out of driving straight if it's drifted a real amount
          if math.abs(diff) > ENTER_TURN then
            setState(diff > 0 and "turnRight" or "turnLeft")
          else
            setState("front") -- no-op, keeps driving
          end
        else
          -- currently turning (or braked/starting) - keep turning until well-aligned
          if math.abs(diff) < EXIT_TURN then
            setState("front")
          else
            setState(diff > 0 and "turnRight" or "turnLeft")
          end
        end
      end
    end
  end

  sleep(TICK)
end

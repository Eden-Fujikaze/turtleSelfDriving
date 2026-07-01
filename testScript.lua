local detector = peripheral.find("player_detector")
local TARGET_NAME = "Eden_Fujikaze"

local RANGE = 50
local MIN_RANGE = 6
local MIN_RANGE_RELEASE = 8
local TURN_DEADZONE = 5
local MOVE_EPS = 0.3

-- five redstone link faces, one per state
local FACE_BRAKE     = "top"
local FACE_REVERSE   = "bottom"   -- gearshift toggle, NOT a drive signal
local FACE_LEFT_BOTH = "left"
local FACE_RIGHT_BOTH= "right"
local FACE_FRONT     = "back"

local REVERSE_ENTER = 100
local FORWARD_ENTER = 80
local MODE_SWITCH_COOLDOWN = 2.0
local TICK = 0.25

if not detector then error("no detector") end

local lastX, lastZ = nil, nil
local heading = 0
local drivingReverse = false   -- gearshift state (persists until toggled again)
local timeSinceSwitch = 999
local tooClose = false

local function normAngle(a)
  a = a % 360
  if a > 180 then a = a - 360 end
  return a
end

-- clears all five faces, then the caller sets exactly the one(s) it wants
local function clearAll()
  redstone.setOutput(FACE_BRAKE, false)
  redstone.setOutput(FACE_LEFT_BOTH, false)
  redstone.setOutput(FACE_RIGHT_BOTH, false)
  redstone.setOutput(FACE_FRONT, false)
  -- FACE_REVERSE is NOT cleared here — it's a toggle, not a drive state
end

-- gearshift is only pulsed when we actually need to flip it
local function setGear(wantReverse)
  if wantReverse ~= drivingReverse then
    redstone.setOutput(FACE_REVERSE, true)
    sleep(0.1) -- adjust to whatever pulse length your gearbox needs
    redstone.setOutput(FACE_REVERSE, false)
    drivingReverse = wantReverse
  end
end

local function driveBrake()
  clearAll()
  redstone.setOutput(FACE_BRAKE, true)
end

local function driveFront()
  clearAll()
  redstone.setOutput(FACE_FRONT, true)
end

local function driveReverseStraight()
  clearAll()
  setGear(true)
  redstone.setOutput(FACE_FRONT, true) -- same wheels engaged, gearbox is what flips direction
end

local function turnLeftInPlace()
  clearAll()
  redstone.setOutput(FACE_LEFT_BOTH, true)
end

local function turnRightInPlace()
  clearAll()
  redstone.setOutput(FACE_RIGHT_BOTH, true)
end

while true do
  local myX, myY, myZ = gps.locate()

  if not myX then
    print("GPS fix failed, skipping this cycle")
  else
    if lastX then
      local mdx, mdz = myX - lastX, myZ - lastZ
      if math.sqrt(mdx * mdx + mdz * mdz) > MOVE_EPS then
        local raw = math.deg(math.atan2(mdz, mdx))
        if drivingReverse then
          heading = normAngle(raw + 180)
        else
          heading = normAngle(raw)
        end
      end
    end
    lastX, lastZ = myX, myZ

    local ok, playerPos = pcall(function() return detector.getPlayerPos(TARGET_NAME) end)

    if not ok or not playerPos then
      print("Could not get player position:", playerPos)
      driveBrake()
    else
      local dx = playerPos.x - myX
      local dz = playerPos.z - myZ
      local distance = math.sqrt(dx * dx + dz * dz)

      if tooClose then
        if distance > MIN_RANGE_RELEASE then
          tooClose = false
        end
      else
        if distance < MIN_RANGE then
          tooClose = true
        end
      end

      if distance > RANGE or tooClose then
        driveBrake()
      else
        local targetAngle = math.deg(math.atan2(dz, dx))
        local fwdDiff = normAngle(targetAngle - heading)

        -- forward/reverse mode hysteresis, same cooldown gate as before
        timeSinceSwitch = timeSinceSwitch + TICK
        local wantReverse = drivingReverse
        if timeSinceSwitch >= MODE_SWITCH_COOLDOWN then
          if drivingReverse then
            if math.abs(fwdDiff) < FORWARD_ENTER then
              wantReverse = false
              timeSinceSwitch = 0
            end
          else
            if math.abs(fwdDiff) > REVERSE_ENTER then
              wantReverse = true
              timeSinceSwitch = 0
            end
          end
        end

        local angleDiff
        if wantReverse then
          angleDiff = normAngle(targetAngle - normAngle(heading + 180))
        else
          angleDiff = fwdDiff
        end

        print(string.format("dist=%.1f heading=%.1f rev=%s diff=%.1f",
          distance, heading, tostring(wantReverse), angleDiff))

        -- decide state for this tick: in-place turn takes priority once
        -- outside the deadzone, otherwise drive straight in current gear direction
        if math.abs(angleDiff) < TURN_DEADZONE then
          if wantReverse then
            driveReverseStraight()
          else
            driveFront()
          end
        elseif angleDiff > 0 then
          setGear(false) -- in-place turns assume forward gear; adjust if your rig needs reverse gear too
          turnRightInPlace()
        else
          setGear(false)
          turnLeftInPlace()
        end
      end
    end
  end

  sleep(TICK)
end

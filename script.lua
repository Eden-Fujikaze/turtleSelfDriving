local detector = peripheral.find("player_detector")

local RANGE = 20
local TARGET_NAME = "EdenFujikaze"

while true do
  local players = detector.getPlayersInRange(RANGE)
  for _, player in ipairs(players) do
    if player.Name == TARGET_NAME then
      local myX, myY, myZ = gps.locate()

      local dx = player.x - myX
      local dz = player.z - myZ

      if math.abs(dx) > math.abs(dz) then
        if dx > 0 then
          redstone.setAnalogOutput("right", 15)
          redstone.setAnalogOutput("left", 0)
        else
          redstone.setAnalogOutput("left", 15)
          redstone.setAnalogOutput("right", 0)
        end
      else
        redstone.setAnalogOutput("left", 0)
        redstone.setAnalogOutput("right", 0)
      end

      redstone.setOutput("front", true)
    end
  end

  sleep(0.25)
end

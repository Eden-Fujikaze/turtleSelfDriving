local geoScanner = peripheral.find("geoScanner")

if not geoScanner then error("no geo scanner found") end

local SCAN_RADIUS = 12 -- covers turtle + 10 blocks behind, plus a little margin

print("Scanning radius " .. SCAN_RADIUS .. "...")

local scan, err = geoScanner.scan(SCAN_RADIUS)

if not scan then
  print("Scan failed: " .. tostring(err))
  return
end

print("Total blocks found: " .. #scan)
print("----")

-- Dump raw shape of the first few entries so we can see exact field names
for i = 1, math.min(5, #scan) do
  local b = scan[i]
  print(string.format("[%d] name=%s  x=%s y=%s z=%s",
    i, tostring(b.name), tostring(b.x), tostring(b.y), tostring(b.z)))
  -- some AP versions also include tags/state - dump full table just in case
  for k, v in pairs(b) do
    if k ~= "name" and k ~= "x" and k ~= "y" and k ~= "z" then
      print("    extra field: " .. tostring(k) .. " = " .. tostring(v))
    end
  end
end

print("----")

-- tally block name -> count, so we can spot anything unusual (like chassis
-- blocks that differ from surrounding terrain) without reading 200 lines
local tally = {}
for _, b in ipairs(scan) do
  tally[b.name] = (tally[b.name] or 0) + 1
end

print("Block name counts:")
for name, count in pairs(tally) do
  print(string.format("  %-40s x%d", name, count))
end

print("----")
print("Look for a block type with a count around 10-11 (your chassis run) that")
print("stands out from terrain block counts. Note its exact 'name' string,")
print("then we can filter scan results by that name to isolate the car body.")

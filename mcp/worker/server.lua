-- Long-lived headless calc worker. Boots the PoB engine once (expensive Data
-- load), then serves one JSON request per input line, one JSON response per
-- output line. Launch via run.sh (sets cwd=src/, CI=1, luarocks paths).

-- stdout is the protocol channel (JSON lines via io.write). Engine chatter goes
-- through print()/ConPrintf, so redirect print -> stderr BEFORE booting to keep
-- stdout clean for the parent's line parser.
local _stderr = io.stderr
print = function(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
  _stderr:write(table.concat(parts, "\t") .. "\n")
end

dofile("../mcp/worker/boot.lua")
package.path = "../mcp/worker/?.lua;" .. package.path
local json = require("json")
local calc = require("calc")
local query = require("query")

io.stdout:setvbuf("line")
-- Tell the parent the (slow) boot finished and we are ready for requests.
io.write(json.encode({ ready = true }) .. "\n")

for line in io.lines() do
  if line ~= "" then
    local ok, result = pcall(function()
      local req = json.decode(line)
      -- data_* ops query static game data and need no build; everything else
      -- is build-scoped and goes through calc.
      if req and query.knows(req.op) then
        return query.handle(req)
      end
      return calc.handle(req)
    end)
    if ok then
      io.write(json.encode({ ok = true, output = result }) .. "\n")
    else
      io.write(json.encode({ ok = false, error = tostring(result) }) .. "\n")
    end
  end
end

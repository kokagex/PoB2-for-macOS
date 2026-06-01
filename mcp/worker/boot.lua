-- Boots the PoB engine headless and defines globals (loadBuildFromXML, build,
-- mainObject) exactly as HeadlessWrapper does.
--
-- Preconditions (handled by run.sh):
--   * cwd == PoB src/  (HeadlessWrapper uses relative dofile("Launch.lua"))
--   * lua-utf8 reachable on LUA_PATH/LUA_CPATH (luarocks)  -> Modules/Common.lua:29
--   * CI=1 in env  -> skip ModCache load on first boot
local probe = io.open("HeadlessWrapper.lua", "r")
assert(probe, "boot.lua: cwd must be the PoB src/ directory")
probe:close()

-- PoB's runtime Lua libs (xml, base64, sha1, dkjson, ...) live in ../runtime/lua;
-- the C host normally puts them on the path. Headless must do it itself.
package.path = "../runtime/lua/?.lua;../runtime/lua/?/init.lua;" .. package.path

dofile("HeadlessWrapper.lua")
assert(_G.build, "boot.lua: engine boot failed (build global is nil)")

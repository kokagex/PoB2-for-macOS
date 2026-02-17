-- test/unit/busted_setup.lua
-- Busted helper: adds test/unit/ to package.path before tests load
package.path = "test/unit/?.lua;" .. package.path

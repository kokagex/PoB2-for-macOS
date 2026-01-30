#!/usr/bin/osascript
-- Path of Building for macOS - AppleScript Launcher
-- This script launches Path of Building with absolute paths

on run
    -- Get the path to the app bundle
    set appPath to (path to me) as text
    set appPOSIXPath to POSIX path of appPath
    set pobRoot to appPOSIXPath & "Contents/Resources/pob2macos/"

    -- Use absolute path to LuaJIT
    set luajitPath to "/usr/local/bin/luajit"

    -- Check if LuaJIT exists
    try
        do shell script "test -x " & quoted form of luajitPath
    on error
        display dialog "LuaJIT is not installed at:" & return & luajitPath & return & return & "Please install it using:" & return & "brew install luajit" buttons {"OK"} default button "OK" with icon stop
        return
    end try

    -- Change to pob2macos directory and launch with absolute path
    -- Use nohup to prevent process termination when AppleScript exits
    set launchScript to "cd " & quoted form of pobRoot & " && nohup " & quoted form of luajitPath & " pob2_launch.lua > ~/Library/Logs/PathOfBuilding.log 2>&1 &"

    -- Launch Path of Building in background
    do shell script launchScript
end run

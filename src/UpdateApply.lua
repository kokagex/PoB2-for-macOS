#@
-- Path of Building
--
-- Module: Update Apply
-- Applies updates.
--
local opFileName = ...

local function normalizePath(path)
	if type(path) ~= "string" then
		return nil
	end
	if path:find("%z", 1, true) then
		return nil
	end
	local normalized = path:gsub("\\", "/"):gsub("/+", "/")
	normalized = normalized:gsub("/+$", "")
	if normalized == "" then
		return "/"
	end
	return normalized
end

local function isWithin(path, root)
	return path == root or path:sub(1, #root + 1) == root.."/"
end

local function hasUnsafeSegments(path)
	return path:find("/%./", 1, true)
		or path:match("/%.$")
		or path:find("/%.%./", 1, true)
		or path:match("/%.%.$")
end

local scriptPath = normalizePath((GetScriptPath and GetScriptPath()) or ".") or "."
local runtimePath = normalizePath((GetRuntimePath and GetRuntimePath()) or scriptPath) or scriptPath
local updatePath = scriptPath.."/Update"

local function validateTargetPath(path)
	local normalized = normalizePath(path)
	if not normalized or normalized:sub(1, 1) ~= "/" then
		return nil
	end
	if normalized:find("[\r\n\"]") or hasUnsafeSegments(normalized) then
		return nil
	end
	if isWithin(normalized, scriptPath) or isWithin(normalized, runtimePath) then
		return normalized
	end
	return nil
end

local function validateUpdateSourcePath(path)
	local normalized = validateTargetPath(path)
	if not normalized then
		return nil
	end
	if not isWithin(normalized, updatePath) then
		return nil
	end
	return normalized
end

print("Applying update...")
local opFile = io.open(opFileName, "r")
if not opFile then
	print("No operations list present.\n")
	return
end
local lines = { }
for line in opFile:lines() do
	table.insert(lines, line)
end
opFile:close()
os.remove(opFileName)
for _, line in ipairs(lines) do
	local op, args = line:match("(%a+) ?(.*)")
	if op == "move" then
		local src, dst = args:match('"(.*)" "(.*)"')
		dst = dst and dst:gsub("{space}", " ")
		src = validateUpdateSourcePath(src or "")
		dst = validateTargetPath(dst or "")
		if not src or not dst then
			print("Skipping unsafe move operation.")
		else
			print("Updating '"..dst.."'")
			local srcFile = io.open(src, "rb")
			if not srcFile then
				print("Skipping move, couldn't open source '"..tostring(src).."'")
			else
				local content = srcFile:read("*a")
				srcFile:close()
				local dstFile
				local openErr
				for _ = 1, 30 do
					dstFile, openErr = io.open(dst, "w+b")
					if dstFile then
						break
					end
				end
				if not dstFile then
					print("Skipping move, couldn't open destination '"..dst.."': "..tostring(openErr))
				else
					dstFile:write(content)
					dstFile:close()
					os.remove(src)
				end
			end
		end
	elseif op == "delete" then
		local file = args:match('"(.*)"')
		file = validateTargetPath(file or "")
		if file then
			print("Deleting '"..file.."'")
			os.remove(file)
		else
			print("Skipping unsafe delete operation.")
		end
	elseif op == "start" then
		local target = args:match('"(.*)"')
		target = validateTargetPath(target or "")
		if target then
			SpawnProcess(target)
		else
			print("Skipping unsafe start operation.")
		end
	end
end

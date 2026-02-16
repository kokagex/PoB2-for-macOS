-- Path of Building
--
-- Module: i18n
-- Internationalization support for multi-language UI
--
local i18n = {}

local locales = {}
local currentLocale = "en"
local fallbackLocale = "en"
local changeCallbacks = setmetatable({}, { __mode = "v" })

-- Auxiliary file mapping: section name → file suffix
-- These files are lazy-loaded on first access instead of at startup
local auxiliaryFiles = {
	gemDescriptions = "_gem_descriptions",
	statDescriptions = "_stat_descriptions",
	gemFlavourText = "_gem_flavourtext",
	uniqueNames = "_unique_names",
	baseNames = "_base_names",
	modStatLines = "_mod_stat_lines",
	uniqueFlavourText = "_unique_flavourtext",
}

-- Track which auxiliary files have been loaded per locale
local auxLoaded = {}

-- Load a single auxiliary file for a locale if not already loaded
local function ensureAuxLoaded(localeCode, section)
	if not localeCode or not auxiliaryFiles[section] then return end
	if not locales[localeCode] then return end
	local key = localeCode .. ":" .. section
	if auxLoaded[key] then return end
	auxLoaded[key] = true
	local suffix = auxiliaryFiles[section]
	local ok, data = pcall(LoadModule, "Locales/" .. localeCode .. suffix)
	if ok and type(data) == "table" then
		locales[localeCode][section] = data
	end
end

-- Load a locale file by code (e.g., "en", "ja")
local function loadLocale(code)
	local ok, data = pcall(LoadModule, "Locales/" .. code)
	if ok and type(data) == "table" then
		locales[code] = data
		return true
	end
	ConPrintf("i18n: Failed to load locale '%s'", tostring(code))
	return false
end

-- Traverse a nested table by dot-separated key path
local function resolve(tbl, keyPath)
	if not tbl then return nil end
	local current = tbl
	for part in keyPath:gmatch("[^%.]+") do
		if type(current) ~= "table" then return nil end
		current = current[part]
	end
	return current
end

-- Initialize i18n with a locale code
function i18n.init(localeCode)
	localeCode = localeCode or "en"
	loadLocale("en")  -- Always load English as fallback
	if localeCode ~= "en" then
		loadLocale(localeCode)
	end
	currentLocale = localeCode
end

-- Get translation for a key path, with optional variable substitution
-- Usage: i18n.t("options.language") or i18n.t("stats.remaining", {count = 5})
function i18n.t(keyPath, vars)
	if not keyPath then return "" end

	-- Try current locale first
	local value = resolve(locales[currentLocale], keyPath)

	-- Fallback to English
	if value == nil and currentLocale ~= fallbackLocale then
		value = resolve(locales[fallbackLocale], keyPath)
	end

	-- Final fallback: return key path itself
	if value == nil then
		return keyPath
	end

	if type(value) ~= "string" then
		return keyPath
	end

	-- Variable substitution: %{varName}
	if vars and type(vars) == "table" then
		value = value:gsub("%%{(%w+)}", function(k)
			local v = vars[k]
			if v ~= nil then
				return tostring(v)
			end
			return "%{" .. k .. "}"
		end)
	end

	return value
end

-- Direct table lookup for keys with special characters (spaces, etc.)
-- Usage: i18n.lookup("gemDescriptions", "Frost Wall") → "ターゲットの前方に..."
function i18n.lookup(section, key)
	if not section or not key then return nil end
	-- Lazy-load auxiliary file if needed
	if auxiliaryFiles[section] then
		ensureAuxLoaded(currentLocale, section)
	end
	local sectionTbl = resolve(locales[currentLocale], section)
	if sectionTbl and type(sectionTbl) == "table" then
		local val = sectionTbl[key]
		if val ~= nil then return val end
	end
	if currentLocale ~= fallbackLocale then
		-- Lazy-load fallback auxiliary file if needed
		if auxiliaryFiles[section] then
			ensureAuxLoaded(fallbackLocale, section)
		end
		sectionTbl = resolve(locales[fallbackLocale], section)
		if sectionTbl and type(sectionTbl) == "table" then
			local val = sectionTbl[key]
			if val ~= nil then return val end
		end
	end
	return nil
end

-- Switch to a different locale at runtime
function i18n.setLocale(localeCode)
	if not localeCode then return end
	if not locales[localeCode] then
		if not loadLocale(localeCode) then
			return
		end
	end
	currentLocale = localeCode
	-- Fire change callbacks (numeric loop to handle weak table nil entries)
	for i = 1, #changeCallbacks do
		local callback = changeCallbacks[i]
		if callback then
			local ok, err = pcall(callback, localeCode)
			if not ok then
				ConPrintf("i18n: onChange callback error: %s", tostring(err))
			end
		end
	end
end

-- Get current locale code
function i18n.getLocale()
	return currentLocale
end

-- Register a callback for locale changes
function i18n.onChange(callback)
	if type(callback) == "function" then
		table.insert(changeCallbacks, callback)
	end
end

-- Remove a previously registered callback
function i18n.removeOnChange(callback)
	for i = #changeCallbacks, 1, -1 do
		if changeCallbacks[i] == callback then
			table.remove(changeCallbacks, i)
			break
		end
	end
end

-- Translate a mod stat line from English to current locale
-- Replaces numeric values with placeholders, looks up translation, restores values
function i18n.translateModLine(line)
	if not line or currentLocale == "en" then return line end
	-- Lazy-load modStatLines if needed
	ensureAuxLoaded(currentLocale, "modStatLines")
	local data = locales[currentLocale]
	if not data or not data.modStatLines then return line end

	local captures = {}
	local PH = "\1"

	local tmpl = line
	-- Step 1: Replace (X-Y) ranges with placeholder
	tmpl = tmpl:gsub("%(%-?[%d%.]+%-%-?[%d%.]+%)", function(r)
		captures[#captures+1] = r
		return PH
	end)
	-- Step 2: Replace # placeholders
	tmpl = tmpl:gsub("#", function()
		captures[#captures+1] = "#"
		return PH
	end)
	-- Step 3: Replace bare numbers
	tmpl = tmpl:gsub("%-?%d+%.?%d*", function(n)
		captures[#captures+1] = n
		return PH
	end)
	-- Step 4: Convert all PH chars to {N} in order
	local idx = 0
	tmpl = tmpl:gsub(PH, function()
		local result = "{" .. idx .. "}"
		idx = idx + 1
		return result
	end)

	local translated = data.modStatLines[tmpl]
	if not translated then return line end

	-- Restore captured values into translated template
	return (translated:gsub("{(%d+)}", function(n)
		return captures[tonumber(n)+1] or ("{" .. n .. "}")
	end))
end

-- Register globally
_G.i18n = i18n

return i18n

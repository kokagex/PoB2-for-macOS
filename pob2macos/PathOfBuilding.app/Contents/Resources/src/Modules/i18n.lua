-- Path of Building
--
-- Module: i18n
-- Internationalization support for multi-language UI
--
local i18n = {}

local locales = {}
local currentLocale = "en"
local fallbackLocale = "en"
local changeCallbacks = {}

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

-- Switch to a different locale at runtime
function i18n.setLocale(localeCode)
	if not localeCode then return end
	if not locales[localeCode] then
		if not loadLocale(localeCode) then
			return
		end
	end
	currentLocale = localeCode
	-- Fire change callbacks
	for _, cb in ipairs(changeCallbacks) do
		local ok, err = pcall(cb, localeCode)
		if not ok then
			ConPrintf("i18n: onChange callback error: %s", tostring(err))
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

-- Register globally
_G.i18n = i18n

return i18n

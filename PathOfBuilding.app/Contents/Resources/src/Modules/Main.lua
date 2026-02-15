-- Path of Building
--
-- Module: Main
-- Main module of program.
--
local ipairs = ipairs
local t_insert = table.insert
local t_remove = table.remove
local m_ceil = math.ceil
local m_floor = math.floor
local m_max = math.max
local m_min = math.min
local m_sin = math.sin
local m_cos = math.cos
local m_pi = math.pi

LoadModule("GameVersions")
LoadModule("Modules/Common")
LoadModule("Modules/Data")
LoadModule("Modules/ModTools")
LoadModule("Modules/ItemTools")
LoadModule("Modules/CalcTools")
LoadModule("Modules/PantheonTools")
LoadModule("Modules/BuildSiteTools")
LoadModule("Modules/i18n")

--[[if launch.devMode then
	for skillName, skill in pairs(data.enchantments.Helmet) do
		for _, mod in ipairs(skill.ENDGAME) do
			local modList, extra = modLib.parseMod(mod)
			if not modList or extra then
				ConPrintf("%s: '%s' '%s'", skillName, mod, extra or "")
			end
		end
	end
end]]

if arg and isValueInTable(arg, "--no-jit") then
	require("jit").off()
	ConPrintf("JIT Disabled")
end

if arg and isValueInTable(arg, "--no-ssl") then
	launch.noSSL = true
	ConPrintf("SSL verification disabled")
end

-- Event object pool to reduce GC pressure
local eventPool = {}
local function acquireEvent()
	local n = #eventPool
	if n > 0 then
		local ev = eventPool[n]
		eventPool[n] = nil
		return ev
	end
	return {}
end
local function releaseEvent(ev)
	ev.type = nil
	ev.key = nil
	ev.val = nil
	ev.doubleClick = nil
	ev.char = nil
	ev.consumed = nil
	eventPool[#eventPool + 1] = ev
end

local tempTable1 = { }
local tempTable2 = { }

main = new("ControlHost")

function main:Init()
	-- Initialize screen scale early for control creation
	self.screenW, self.screenH = GetScreenSize()
	self.screenScale = 1  -- DPI scaling handled at FFI level

	-- i18n initialization
	self.language = "en"
	if i18n and i18n.init then i18n.init("en") end
	if data and data.rebuildItemListLabels then data.rebuildItemListLabels() end
	if SetFontScale then SetFontScale(1.0) end

	self:DetectUnicodeSupport()
	self.modes = { }
	self.modes["LIST"] = LoadModule("Modules/BuildList")
	self.modes["BUILD"] = LoadModule("Modules/Build")

	self.popups = { }
	self.sharedItemList = { }
	self.sharedItemSetList = { }
	self.gameAccounts = { }

	local ignoreBuild
	if arg[1] then
		local importLink = buildSites.ParseImportLinkFromURI(arg[1])
		buildSites.DownloadBuild(arg[1], nil, function(isSuccess, data, importLink)
			if not isSuccess then
				self:SetMode("BUILD", false, data)
			else
				local xmlText = Inflate(common.base64.decode(data:gsub("-","+"):gsub("_","/")))
				self:SetMode("BUILD", false, "Imported Build", xmlText, false, importLink)
				self.newModeChangeToTree = true
			end
		end)
		arg[1] = nil -- Protect against downloading again this session.
		ignoreBuild = true
	end

	-- Start with LIST mode to properly initialize, then auto-transition to BUILD
	self.autoStartBuild = not ignoreBuild
	if not ignoreBuild then
		self:SetMode("LIST")
	end
	if launch.devMode or (GetScriptPath() == GetRuntimePath() and not launch.installedMode) then
		-- If running in dev mode or standalone mode, put user data in the script path
		self.userPath = GetScriptPath().."/"
	else
		local invalidPath, errMsg
		self.userPath, invalidPath, errMsg = GetUserPath()
		if not self.userPath then
			self:OpenPathPopup(invalidPath, errMsg, ignoreBuild)
		else
			self.userPath = self.userPath.."/Path of Building/"
		end
	end

	self.buildSortMode = "NAME"
	self.connectionProtocol = 0
	self.nodePowerTheme = "RED/BLUE"
	self.language = self.language or "en"
	self.colorPositive = defaultColorCodes.POSITIVE
	self.colorNegative = defaultColorCodes.NEGATIVE
	self.colorHighlight = defaultColorCodes.HIGHLIGHT
	self.showThousandsSeparators = true
	self.edgeSearchHighlight = true
	self.thousandsSeparator = ","
	self.decimalSeparator = "."
	self.defaultItemAffixQuality = 0.5
	self.showTitlebarName = true
	self.dpiScaleOverridePercent = GetDPIScaleOverridePercent and GetDPIScaleOverridePercent() or 0
	self.showWarnings = true
	self.slotOnlyTooltips = true
	self.notSupportedModTooltips = true
	self.notSupportedTooltipText = i18n.t("general.notSupportedTooltip")
	self.POESESSID = ""
	self.showPublicBuilds = true
	self.showFlavourText = true
	self.showAnimations = true
	self.showAllItemAffixes = true
	self.errorReadingSettings = false

	if not SetDPIScaleOverridePercent then SetDPIScaleOverridePercent = function(scale) end end

	if launch.devMode and IsKeyDown("CTRL") or os.getenv("REGENERATE_MOD_CACHE") == "1" then
		-- If modLib.parseMod doesn't find a cache entry it generates it.
		-- Not loading pre-generated cache causes it to be rebuilt
		self.saveNewModCache = true
	else
		-- Load mod cache
		LoadModule("Data/ModCache", modLib.parseModCache)
	end

	--[[ this does not work properly anymore see PR #7675
	if launch.devMode and IsKeyDown("CTRL") and IsKeyDown("SHIFT") then
		self.allowTreeDownload = true
	end
	--]]

	self.inputEvents = { }
	self.tooltipLines = { }

	self.tree = { }
	self:LoadTree(latestTreeVersion)

	if self.userPath then
		self:ChangeUserPath(self.userPath, ignoreBuild)
	end

	self.uniqueDB = { list = { }, loading = true }
	self.rareDB = { list = { }, loading = true }

	local function loadItemDBs()
		for type, typeList in pairsYield(data.uniques) do
			for _, raw in pairs(typeList) do
				local ok, result = pcall(new, "Item", raw, "UNIQUE", true)
				if ok then
					newItem = result
					if newItem.base then
						self.uniqueDB.list[newItem.name] = newItem
					elseif launch.devMode then
						ConPrintf("Unique DB unrecognised item of type '%s':\n%s", type, raw)
					end
				else
					ConPrintf("Unique DB error loading item of type '%s': %s", type, tostring(result))
					local ef = io.open("/tmp/pob_unique_errors.txt", "a")
					if ef then ef:write(type .. ": " .. tostring(result) .. "\n") ef:close() end
				end
			end
		end

		self.uniqueDB.loading = nil
		ConPrintf("Uniques loaded")

		for _, raw in pairsYield(data.rares) do
			newItem = new("Item", raw, "RARE", true)
			if newItem.base then
				if newItem.crafted then
					if newItem.base.implicit and #newItem.implicitModLines == 0 then
						-- Automatically add implicit
						local implicitIndex = 1
						for line in newItem.base.implicit:gmatch("[^\n]+") do
							t_insert(newItem.implicitModLines, { line = line, modTags = newItem.base.implicitModTypes and newItem.base.implicitModTypes[implicitIndex] or { } })
							implicitIndex = implicitIndex + 1
						end
					end
					newItem:Craft()
				end
				self.rareDB.list[newItem.name] = newItem
			elseif launch.devMode then
				ConPrintf("Rare DB unrecognised item:\n%s", raw)
			end
		end

		self.rareDB.loading = nil
		ConPrintf("Rares loaded")
	end

	if self.saveNewModCache then
		local saved = self.defaultItemAffixQuality
		self.defaultItemAffixQuality = 0.5
		loadItemDBs()
		self:SaveModCache()
		self.defaultItemAffixQuality = saved
	end

	local s = self.screenScale
	self.anchorMain = new("Control", nil, {4 * s, 0, 0, 0})
	self.anchorMain.y = function()
		return self.screenH - 4 * s
	end
	self.controls.options = new("ButtonControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, {0, 0, 68 * s, 20 * s}, i18n.t("general.options"), function()
		self:OpenOptionsPopup()
	end)
	self.controls.about = new("ButtonControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, {72 * s, 0, 68 * s, 20 * s}, i18n.t("general.about"), function()
		self:OpenAboutPopup()
	end)
	self.controls.applyUpdate = new("ButtonControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, {0, -24 * s, 140 * s, 20 * s}, "^x50E050" .. i18n.t("general.updateReady"), function()
		self:OpenUpdatePopup()
	end)
	self.controls.applyUpdate.shown = function()
		return launch.updateAvailable and launch.updateAvailable ~= "none"
	end
	self.controls.checkUpdate = new("ButtonControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, {0, -24 * s, 140 * s, 20 * s}, "", function()
		launch:CheckForUpdate()
	end)
	self.controls.checkUpdate.shown = function()
		return not launch.devMode and (not launch.updateAvailable or launch.updateAvailable == "none")
	end
	self.controls.checkUpdate.label = function()
		return launch.updateCheckRunning and launch.updateProgress or i18n.t("general.checkForUpdate")
	end
	self.controls.checkUpdate.enabled = function()
		return not launch.updateCheckRunning
	end
	self.controls.forkLabel = new("LabelControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, {148 * s, -26 * s, 0, 16 * s}, "")
	self.controls.forkLabel.label = function()
		return "^8PoB Community Fork"
	end
	self.controls.versionLabel = new("LabelControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, {148 * s, -2 * s, 0, 16 * s}, "")
	self.controls.versionLabel.label = function()
		return "^8" .. (launch.versionBranch == "beta" and "Beta: " or "Version: ") .. launch.versionNumber .. (launch.versionBranch == "dev" and " (Dev)" or "")
	end
	self.controls.devMode = new("LabelControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, {0, -26 * s, 0, 20 * s}, colorCodes.NEGATIVE.."Dev Mode")
	self.controls.devMode.shown = function()
		return launch.devMode
	end
	self.controls.dismissToast = new("ButtonControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, {0, function() return -self.mainBarHeight + self.toastHeight end, 80 * s, 20 * s}, i18n.t("general.dismiss"), function()
		self.toastMode = "HIDING"
		self.toastStart = GetTime()
	end)
	self.controls.dismissToast.shown = function()
		return self.toastMode == "SHOWN"
	end

	self.mainBarHeight = 58 * s
	self.toastMessages = { }

	if launch.devMode and GetTime() >= 0 and GetTime() < 15000 then
		t_insert(self.toastMessages, [[
^xFF7700Warning: ^7Developer Mode active!
The program is currently running in developer
mode, which is not intended for normal use.
If you are not expecting this, then you may have
set up the program from the source .zip instead
of using one of the installers. If that is the case,
please reinstall using one of the installers from
the "Releases" section of the GitHub page.]])
	end

	self.onFrameFuncs = {
		["FirstFrame"] = function()
			self.onFrameFuncs["FirstFrame"] = nil
			if launch.devMode then
				data.printMissingMinionSkills()
			end
			ConPrintf("Startup time: %d ms", GetTime() - launch.startTime)
		end
	}

	if not self.saveNewModCache then
		local itemsCoroutine = coroutine.create(loadItemDBs)

		self.onFrameFuncs["LoadItems"] = function()
			local res, errMsg = coroutine.resume(itemsCoroutine)
			if coroutine.status(itemsCoroutine) == "dead" then
				self.onFrameFuncs["LoadItems"] = nil
			end
			if not res then
				error(errMsg)
			end
		end
	end
end

function main:DetectUnicodeSupport()
	-- PoeCharm has utf8 global that normal PoB doesn't have
	self.unicode = type(_G.utf8) == "table"
	-- Enable unicode for CJK locales (Japanese font + CharInput.dylib provide full support)
	if not self.unicode and i18n and i18n.getLocale() ~= "en" then
		self.unicode = true
	end
	if self.unicode then
		ConPrintf("Unicode support detected")
	end
end

function main:SaveModCache()
	-- Update mod cache
	local out = io.open("Data/ModCache.lua", "w")
	out:write('local c=...')
	for line, dat in pairsSortByKey(modLib.parseModCache) do
		if not dat[1] or not dat[1][1] or (dat[1][1].name ~= "JewelFunc" and dat[1][1].name ~= "ExtraJewelFunc") then
			out:write('c["', line:gsub("\n","\\n"), '"]={')
			if dat[1] then
				writeLuaTable(out, dat[1])
			else
				out:write('nil')
			end
			if dat[2] then
				out:write(',"', dat[2]:gsub("\n","\\n"), '"}\n')
			else
				out:write(',nil}\n')
			end
		end
	end
	out:close()
end

function main:LoadTree(treeVersion)
	if self.tree[treeVersion] then
		data.setJewelRadiiGlobally(treeVersion)
		return self.tree[treeVersion]
	elseif isValueInTable(treeVersionList, treeVersion) then
		data.setJewelRadiiGlobally(treeVersion)
		--ConPrintf("[main:LoadTree] - Lazy Loading Tree " .. treeVersion)
		self.tree[treeVersion] = new("PassiveTree", treeVersion)
		return self.tree[treeVersion]
	end
	return nil
end

function main:CanExit()
	local ret = self:CallMode("CanExit", "EXIT")
	if ret ~= nil then
		return ret
	else
		return true
	end
end

function main:Shutdown()
	self:CallMode("Shutdown")
	self:SaveSettings()
end

function main:OnFrame()
	self.screenW, self.screenH = GetScreenSize()
	-- DPI scaling handled at FFI level in pob2_launch.lua; screenScale=1
	self.screenScale = 1

	if self.screenH > self.screenW then
		self.portraitMode = true
	else
		self.portraitMode = false
	end

	while self.newMode do
		if self.mode then
			self:CallMode("Shutdown")
		end
		self.mode = self.newMode
		self.newMode = nil
		self:CallMode("Init", unpack(self.newModeArgs))
		if self.newModeChangeToTree then
			self.modes[self.mode].viewMode = "TREE"
		end
		self.newModeChangeToTree = false
	end

	-- Auto-transition from LIST to BUILD mode on startup
	if self.autoStartBuild and self.mode == "LIST" then
		self.autoStartBuild = false
		self:SetMode("BUILD", false, "Unnamed build")
		return  -- Skip this frame's rendering, let next frame handle BUILD mode
	end

	self.viewPort = { x = 0, y = 0, width = self.screenW, height = self.screenH }

	if self.popups[1] then
		self.popups[1]:ProcessInput(self.inputEvents, self.viewPort)
		for i = 1, #self.inputEvents do
			releaseEvent(self.inputEvents[i])
		end
		wipeTable(self.inputEvents)
	else
		if self.selControl and not self.selControl.OnChar then
			for _, event in ipairs(self.inputEvents) do
				if event.type == "KeyDown" and not event.key:match("BUTTON") then
					self:SelectControl()
					break
				end
			end
		end
		self:ProcessControlsInput(self.inputEvents, self.viewPort)
	end

	self:CallMode("OnFrame", self.inputEvents, self.viewPort)

	if launch.updateErrMsg then
		t_insert(self.toastMessages, string.format(i18n.t("general.updateCheckFailed"), launch.updateErrMsg))
		launch.updateErrMsg = nil
	end
	if launch.updateAvailable then
		if launch.updateAvailable == "none" then
			t_insert(self.toastMessages, i18n.t("general.noUpdateAvailable"))
			launch.updateAvailable = nil
		elseif not self.updateAvailableShown then
			t_insert(self.toastMessages, i18n.t("general.updateDownloaded"))
			self.updateAvailableShown = true
		end
	end

	-- Run toasts
	if self.toastMessages[1] then
		if not self.toastMode then
			self.toastMode = "SHOWING"
			self.toastStart = GetTime()
			self.toastHeight = #self.toastMessages[1]:gsub("[^\n]","") * 16 + 20 + 40
		end
		if self.toastMode == "SHOWING" then
			local now = GetTime()
			if now >= self.toastStart + 250 then
				self.toastMode = "SHOWN"
			else
				self.mainBarHeight = 58 + self.toastHeight * (now - self.toastStart) / 250
			end
		end
		if self.toastMode == "SHOWN" then
			self.mainBarHeight = 58 + self.toastHeight
		elseif self.toastMode == "HIDING" then
			local now = GetTime()
			if now >= self.toastStart + 75 then
				self.toastMode = nil
				self.mainBarHeight = 58
				t_remove(self.toastMessages, 1)
			else
				self.mainBarHeight = 58 + self.toastHeight * (1 - (now - self.toastStart) / 75)
			end
		end
		if self.toastMode then
			local s = self.screenScale
			SetDrawColor(0.85, 0.85, 0.85)
			DrawImage(nil, 0, self.screenH - self.mainBarHeight, 312 * s, self.mainBarHeight)
			SetDrawColor(0.1, 0.1, 0.1)
			DrawImage(nil, 0, self.screenH - self.mainBarHeight + 4 * s, 308 * s, self.mainBarHeight - 4 * s)
			SetDrawColor(1, 1, 1)
			DrawString(4 * s, self.screenH - self.mainBarHeight + 8 * s, "LEFT", 20 * s, "VAR", self.toastMessages[1]:gsub("\n.*",""))
			DrawString(4 * s, self.screenH - self.mainBarHeight + 28 * s, "LEFT", 16 * s, "VAR", self.toastMessages[1]:gsub("^[^\n]*\n?",""))
		end
	end

	-- Draw main controls
	local s = self.screenScale
	SetDrawColor(0.85, 0.85, 0.85)
	DrawImage(nil, 0, self.screenH - 58 * s, 312 * s, 58 * s)
	SetDrawColor(0.1, 0.1, 0.1)
	DrawImage(nil, 0, self.screenH - 54 * s, 308 * s, 54 * s)
	self:DrawControls(self.viewPort)

	-- Flush deferred tooltips AFTER all controls (Build + Main bottom bar) are drawn
	if main.tooltipQueue then
		for _, drawFunc in ipairs(main.tooltipQueue) do
			drawFunc()
		end
		wipeTable(main.tooltipQueue)
	end

	if self.popups[1] then
		SetDrawLayer(10)
		SetDrawColor(0, 0, 0, 0.5)
		DrawImage(nil, 0, 0, self.screenW, self.screenH)
		self.popups[1]:Draw(self.viewPort)
		SetDrawLayer(0)
	end

	if self.showDragText then
		local cursorX, cursorY = GetCursorPos()
		local strWidth = DrawStringWidth(16, "VAR", self.showDragText)
		SetDrawLayer(20, 0)
		SetDrawColor(0.15, 0.15, 0.15, 0.75)
		DrawImage(nil, cursorX, cursorY - 8, strWidth + 2, 18)
		SetDrawColor(1, 1, 1)
		DrawString(cursorX + 1, cursorY - 7, "LEFT", 16, "VAR", self.showDragText)
		self.showDragText = nil
	end

	--[[local par = 300
	for x = 0, 750 do
		for y = 0, 750 do
			local dpsCol = (x / par * 1.5) ^ 0.5
			local defCol = (y / par * 1.5) ^ 0.5
			local mixCol = (m_max(dpsCol - 0.5, 0) + m_max(defCol - 0.5, 0)) / 2
			if main.nodePowerTheme == "RED/BLUE" then
				SetDrawColor(dpsCol, mixCol, defCol)
			elseif main.nodePowerTheme == "RED/GREEN" then
				SetDrawColor(dpsCol, defCol, mixCol)
			elseif main.nodePowerTheme == "GREEN/BLUE" then
				SetDrawColor(mixCol, dpsCol, defCol)
			end
			DrawImage(nil, x + 500, y + 200, 1, 1)
		end
	end
	SetDrawColor(0, 0, 0)
	DrawImage(nil, par + 500, 200, 2, 750)
	DrawImage(nil, 500, par + 200, 759, 2)]]
	
	if self.inputEvents and not itemLib.wiki.triggered then
		for _, event in ipairs(self.inputEvents) do
			if event.type == "KeyUp" and event.key == "F1" then
				local tabName = (self.modes[self.mode].viewMode and self.modes[self.mode].viewMode:lower() or "Build List") .. " tab"
				self:OpenAboutPopup(tabName or 1)
				break
			end
		end
	end
	itemLib.wiki.triggered = false

	for i = 1, #self.inputEvents do
		releaseEvent(self.inputEvents[i])
	end
	wipeTable(self.inputEvents)

	-- TODO: this pattern may pose memory management issues for classes that don't exist for the lifetime of the program
	for _, onFrameFunc in pairs(self.onFrameFuncs) do
		onFrameFunc()
	end
	collectgarbage("step", 10)
end

function main:OnKeyDown(key, doubleClick)
	local ev = acquireEvent()
	ev.type = "KeyDown"
	ev.key = key
	ev.doubleClick = doubleClick
	t_insert(self.inputEvents, ev)
end

function main:OnKeyUp(key)
	local ev = acquireEvent()
	ev.type = "KeyUp"
	ev.key = key
	t_insert(self.inputEvents, ev)
end

function main:OnChar(key)
	local ev = acquireEvent()
	ev.type = "Char"
	ev.key = key
	t_insert(self.inputEvents, ev)
end

function main:SetMode(newMode, ...)
	self.newMode = newMode
	self.newModeArgs = {...}
	self.predefinedBuildName = nil
end

function main:CallMode(func, ...)
	local modeTbl = self.modes[self.mode]
	if modeTbl and modeTbl[func] then
		return modeTbl[func](modeTbl, ...)
	else
		ConPrintf("WARNING: Mode %s does not have function %s", tostring(self.mode), tostring(func))
	end
end

function main:LoadSettings(ignoreBuild)
	if self.errorReadingSettings then
		return true
	end
	local setXML, errMsg = common.xml.LoadXMLFile(self.userPath.."Settings.xml")
	if errMsg and errMsg:match(".*file returns nil") then
		self.errorReadingSettings = true
		self:OpenCloudErrorPopup(self.userPath.."Settings.xml")
		return true
	elseif errMsg and not errMsg:match(".*No such file or directory") then
		self.errorReadingSettings = true
		launch:ShowErrMsg("^1"..errMsg)
		return true
	end
	if not setXML then
		return true
	elseif setXML[1].elem ~= "PathOfBuilding" then
		launch:ShowErrMsg(i18n.t("general.errorParsingSettingsRoot"))
		return true
	end
	for _, node in ipairs(setXML[1]) do
		if type(node) == "table" then
			if not ignoreBuild and node.elem == "Mode" then
				if not node.attrib.mode or not self.modes[node.attrib.mode] then
					launch:ShowErrMsg(i18n.t("general.errorParsingSettingsMode"))
					return true
				end
				local args = { }
				for _, child in ipairs(node) do
					if type(child) == "table" then
						if child.elem == "Arg" then
							if child.attrib.number then
								t_insert(args, tonumber(child.attrib.number))
							elseif child.attrib.string then
								t_insert(args, child.attrib.string)
							elseif child.attrib.boolean then
								t_insert(args, child.attrib.boolean == "true")
							end
						end
					end
				end
				self:SetMode(node.attrib.mode, unpack(args))
			elseif node.elem == "Accounts" then
				self.lastAccountName = node.attrib.lastAccountName
				self.lastRealm = node.attrib.lastRealm
				for _, child in ipairs(node) do
					if child.elem == "Account" then
						self.gameAccounts[child.attrib.accountName] = {
							sessionID = child.attrib.sessionID,
						}
					end
				end
			elseif node.elem == "Misc" then
				if node.attrib.buildSortMode then
					self.buildSortMode = node.attrib.buildSortMode
				end
				launch.connectionProtocol = tonumber(node.attrib.connectionProtocol)
				launch.proxyURL = node.attrib.proxyURL
				if node.attrib.buildPath then
					self.buildPath = node.attrib.buildPath
				end
				if node.attrib.nodePowerTheme then
					self.nodePowerTheme = node.attrib.nodePowerTheme
				end
				if node.attrib.language then
					self.language = node.attrib.language
					if i18n and i18n.setLocale then
						i18n.setLocale(self.language)
						self.notSupportedTooltipText = i18n.t("general.notSupportedTooltip")
					end
					if data and data.rebuildItemListLabels then data.rebuildItemListLabels() end
					if SetFontScale then
						SetFontScale(self.language == "ja" and 0.93 or 1.0)
					end
				end
				if node.attrib.colorPositive then
					updateColorCode("POSITIVE", node.attrib.colorPositive)
					self.colorPositive = node.attrib.colorPositive
				end
				if node.attrib.colorNegative then
					updateColorCode("NEGATIVE", node.attrib.colorNegative)
					self.colorNegative = node.attrib.colorNegative
				end
				if node.attrib.colorHighlight then
					updateColorCode("HIGHLIGHT", node.attrib.colorHighlight)
					self.colorHighlight = node.attrib.colorHighlight
				end

				-- In order to preserve users' settings through renaming/merging this variable, we have this if statement to use the first found setting
				-- Once the user has closed PoB once, they will be using the new `showThousandsSeparator` variable name, so after some time, this statement may be removed
				if node.attrib.showThousandsCalcs then
					self.showThousandsSeparators = node.attrib.showThousandsCalcs == "true"
				elseif node.attrib.showThousandsSidebar then
					self.showThousandsSeparators = node.attrib.showThousandsSidebar == "true"
				end
				if node.attrib.showThousandsSeparators then
					self.showThousandsSeparators = node.attrib.showThousandsSeparators == "true"
				end
				if node.attrib.thousandsSeparator then
					self.thousandsSeparator = node.attrib.thousandsSeparator
				end
				if node.attrib.decimalSeparator then
					self.decimalSeparator = node.attrib.decimalSeparator
				end
				if node.attrib.showTitlebarName then
					self.showTitlebarName = node.attrib.showTitlebarName == "true"
				end
				if node.attrib.betaTest then
					self.betaTest = node.attrib.betaTest == "true"
				end
				if node.attrib.edgeSearchHighlight then
					self.edgeSearchHighlight = node.attrib.edgeSearchHighlight == "true"
				end
				if node.attrib.defaultGemQuality then
					self.defaultGemQuality = m_min(tonumber(node.attrib.defaultGemQuality) or 0, 23)
				end
				if node.attrib.defaultCharLevel then
					self.defaultCharLevel = m_min(m_max(tonumber(node.attrib.defaultCharLevel) or 1, 1), 100)
				end
				if node.attrib.defaultItemAffixQuality then
					self.defaultItemAffixQuality = m_min(tonumber(node.attrib.defaultItemAffixQuality) or 0.5, 1)
				end
				if node.attrib.lastExportedWebsite then
					self.lastExportedWebsite = node.attrib.lastExportedWebsite
				end
				if node.attrib.showWarnings then
					self.showWarnings = node.attrib.showWarnings == "true"
				end
				if node.attrib.slotOnlyTooltips then
					self.slotOnlyTooltips = node.attrib.slotOnlyTooltips == "true"
				end
				if node.attrib.notSupportedModTooltips then
					self.notSupportedModTooltips = node.attrib.notSupportedModTooltips == "true"
				end
				if node.attrib.POESESSID then
					self.POESESSID = node.attrib.POESESSID or ""
				end
				if node.attrib.invertSliderScrollDirection then
					self.invertSliderScrollDirection = node.attrib.invertSliderScrollDirection == "true"
				end
				if node.attrib.disableDevAutoSave then
					self.disableDevAutoSave = node.attrib.disableDevAutoSave == "true"
				end
				if node.attrib.showPublicBuilds then
					self.showPublicBuilds = node.attrib.showPublicBuilds == "true"
				end
				if node.attrib.showFlavourText then
					self.showFlavourText = node.attrib.showFlavourText == "true"
				end
				if node.attrib.showAnimations then
					self.showAnimations = node.attrib.showAnimations == "true"
				end
				if node.attrib.showAllItemAffixes then
					self.showAllItemAffixes = node.attrib.showAllItemAffixes == "true"
				end
				if node.attrib.dpiScaleOverridePercent then
					self.dpiScaleOverridePercent = tonumber(node.attrib.dpiScaleOverridePercent) or 0
					SetDPIScaleOverridePercent(self.dpiScaleOverridePercent)
				end
			end
		end
	end
end

function main:LoadSharedItems()
	if self.errorReadingSettings then
		return true
	end
	local setXML, errMsg = common.xml.LoadXMLFile(self.userPath.."Settings.xml")
	if errMsg and errMsg:match(".*file returns nil") then
		self.errorReadingSettings = true
		self:OpenCloudErrorPopup(self.userPath.."Settings.xml")
		return true
	elseif errMsg and not errMsg:match(".*No such file or directory") then
		self.errorReadingSettings = true
		launch:ShowErrMsg("^1"..errMsg)
		return true
	end
	if not setXML then
		return true
	elseif setXML[1].elem ~= "PathOfBuilding" then
		launch:ShowErrMsg(i18n.t("general.errorParsingSettingsRoot"))
		return true
	end
	for _, node in ipairs(setXML[1]) do
		if type(node) == "table" then
			if node.elem == "SharedItems" then
				for _, child in ipairs(node) do
					if child.elem == "Item" then
						local rawItem = { raw = "" }
						for _, subChild in ipairs(child) do
							if type(subChild) == "string" then
								rawItem.raw = subChild
							end
						end
						local newItem = new("Item", rawItem.raw)
						t_insert(self.sharedItemList, newItem)
					elseif child.elem == "ItemSet" then
						local sharedItemSet = { title = child.attrib.title, slots = { } }
						for _, grandChild in ipairs(child) do
							if grandChild.elem == "Item" then
								local rawItem = { raw = "" }
								for _, subChild in ipairs(grandChild) do
									if type(subChild) == "string" then
										rawItem.raw = subChild
									end
								end
								local newItem = new("Item", rawItem.raw)
								sharedItemSet.slots[grandChild.attrib.slotName] = newItem
							end
						end
						t_insert(self.sharedItemSetList, sharedItemSet)
					end
				end
			end
		end
	end
end

function main:SaveSettings()
	if self.errorReadingSettings then
		return
	end
	local setXML = { elem = "PathOfBuilding" }
	local mode = { elem = "Mode", attrib = { mode = self.mode } }
	for _, val in ipairs({ self:CallMode("GetArgs") }) do
		local child = { elem = "Arg", attrib = { } }
		if type(val) == "number" then
			child.attrib.number = tostring(val)
		elseif type(val) == "boolean" then
			child.attrib.boolean = tostring(val)
		else
			child.attrib.string = tostring(val)
		end
		t_insert(mode, child)
	end

	-- if setting save is attempted and mode is nil something has gone very wrong
	if not mode.attrib.mode or not mode[1] then
		launch:ShowErrMsg(i18n.t("general.errorSavingSettingsMode"))
		return true
	end
	t_insert(setXML, mode)
	local accounts = { elem = "Accounts", attrib = { lastAccountName = self.lastAccountName, lastRealm = self.lastRealm } }
	for accountName, account in pairs(self.gameAccounts) do
		t_insert(accounts, { elem = "Account", attrib = { accountName = accountName, sessionID = account.sessionID } })
	end
	t_insert(setXML, accounts)
	local sharedItemList = { elem = "SharedItems" }
	for _, verItem in ipairs(self.sharedItemList) do
		t_insert(sharedItemList, { elem = "Item", [1] = verItem.raw })
	end
	for _, sharedItemSet in ipairs(self.sharedItemSetList) do
		local set = { elem = "ItemSet", attrib = { title = sharedItemSet.title } }
		for slotName, verItem in pairs(sharedItemSet.slots) do
			t_insert(set, { elem = "Item", attrib = { slotName = slotName }, [1] = verItem.raw })
		end
		t_insert(sharedItemList, set)
	end
	t_insert(setXML, sharedItemList)
	t_insert(setXML, { elem = "Misc", attrib = {
		buildSortMode = self.buildSortMode,
		connectionProtocol = tostring(launch.connectionProtocol),
		proxyURL = launch.proxyURL,
		buildPath = (self.buildPath ~= self.defaultBuildPath and self.buildPath or nil),
		nodePowerTheme = self.nodePowerTheme,
		language = self.language,
		colorPositive = self.colorPositive,
		colorNegative = self.colorNegative,
		colorHighlight = self.colorHighlight,
		showThousandsSeparators = tostring(self.showThousandsSeparators),
		thousandsSeparator = self.thousandsSeparator,
		decimalSeparator = self.decimalSeparator,
		showTitlebarName = tostring(self.showTitlebarName),
		betaTest = tostring(self.betaTest),
		edgeSearchHighlight = tostring(self.edgeSearchHighlight),
		defaultGemQuality = tostring(self.defaultGemQuality or 0),
		defaultCharLevel = tostring(self.defaultCharLevel or 1),
		defaultItemAffixQuality = tostring(self.defaultItemAffixQuality or 0.5),
		lastExportedWebsite = self.lastExportedWebsite,
		showWarnings = tostring(self.showWarnings),
		slotOnlyTooltips = tostring(self.slotOnlyTooltips),
		notSupportedModTooltips = tostring(self.notSupportedModTooltips),
		POESESSID = self.POESESSID,
		invertSliderScrollDirection = tostring(self.invertSliderScrollDirection),
		disableDevAutoSave = tostring(self.disableDevAutoSave),
		showPublicBuilds = tostring(self.showPublicBuilds),
		showFlavourText = tostring(self.showFlavourText),
		showAnimations = tostring(self.showAnimations),
		showAllItemAffixes = tostring(self.showAllItemAffixes),
		dpiScaleOverridePercent = tostring(self.dpiScaleOverridePercent),
	} })
	local res, errMsg = common.xml.SaveXMLFile(setXML, self.userPath.."Settings.xml")
	if not res then
		launch:ShowErrMsg(string.format(i18n.t("general.errorSavingSettings"), errMsg))
		return true
	end
end

function main:OpenPathPopup(invalidPath, errMsg, ignoreBuild)
	local controls = { }
	local defaultLabelPlacementX = 8

	controls.label = new("LabelControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, 20, 206, 16 }, function()
		return i18n.t("general.settingsPathCannotLoad").. errMsg ..
		i18n.t("general.settingsPathCurrentPath")..invalidPath:gsub("?", "^1?^7").."/Path of Building/"..
		i18n.t("general.settingsPathOneDrive1") ..
		i18n.t("general.settingsPathOneDrive2") ..
		i18n.t("general.settingsPathNewLocation")
	end)
	controls.userPath = new("EditControl", { "TOPLEFT", controls.label, "TOPLEFT" }, { 0, 60, 206, 20 }, invalidPath, nil, nil, nil, function(buf)
		invalidPath = sanitiseText(buf)
		if not invalidPath:match("?") then
			controls.save.enabled = true
		else
			controls.save.enabled = false
		end
	end)
	controls.save = new("ButtonControl", { "TOPLEFT", controls.userPath, "TOPLEFT" }, { 0, 26, 206, 20 }, i18n.t("general.save"), function()
		local res, msg = MakeDir(controls.userPath.buf)
		if not res and msg ~= "No error" then
			self:OpenMessagePopup(i18n.t("general.error"), "Couldn't create '"..controls.userPath.buf.."' : "..msg)
		else
			self:ChangeUserPath(controls.userPath.buf, ignoreBuild)
			self:ClosePopup()
		end
	end)
	controls.save.enabled = false
	controls.cancel = new("ButtonControl", nil, { 0, 0, 0, 0 }, i18n.t("general.cancel"), function()
		-- Do nothing, require user to enter a location
	end)
	self:OpenPopup(600, 150, i18n.t("general.changeSettingsPath"), controls, "save", nil, "cancel")
end

function main:ChangeUserPath(newUserPath, ignoreBuild)
	self.userPath = newUserPath
	MakeDir(self.userPath)
	self.defaultBuildPath = self.userPath.."Builds/"
	self.buildPath = self.defaultBuildPath
	MakeDir(self.buildPath)
	self:LoadSettings(ignoreBuild)
	self:LoadSharedItems()
end

function main:OpenOptionsPopup()
	local controls = { }
	local s = self.screenScale or 1

	local currentY = 20 * s
	local isJapanese = (i18n and i18n.getLocale and i18n.getLocale() == "ja")
	local popupWidth = isJapanese and (800 * s) or (600 * s)

	-- local func to make a new line with a heightModifier
	local function nextRow(heightModifier)
		local pxPerLine = 26 * s
		heightModifier = heightModifier or 1
		currentY = currentY + heightModifier * pxPerLine
	end

	-- local func to make a new section header
	local function drawSectionHeader(id, title, omitHorizontalLine)
		local headerBGColor ={ .6, .6, .6}
		controls["section-"..id .. "-bg"] = new("RectangleOutlineControl", { "TOPLEFT", nil, "TOPLEFT" }, { 8 * s, currentY, popupWidth - 17 * s, 26 * s }, headerBGColor, 1)
		nextRow(.2)
		controls["section-"..id .. "-label"] = new("LabelControl", { "TOPLEFT", nil, "TOPLEFT" }, { popupWidth / 2 - 60 * s, currentY, 0, 16 * s }, "^7" .. title)
		nextRow(1.5)
	end

	local defaultLabelSpacingPx = isJapanese and (-20 * s) or (-4 * s)
	local defaultLabelPlacementX = isJapanese and (280 * s) or (240 * s)

	drawSectionHeader("app", i18n.t("options.app.header"))

	controls.language = new("DropDownControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 150 * s, 18 * s }, {
		{ label = "English", code = "en" },
		{ label = "日本語 (Japanese)", code = "ja" },
	}, function(index, value)
		self.language = value.code
		if i18n and i18n.setLocale then
			i18n.setLocale(value.code)
			self.notSupportedTooltipText = i18n.t("general.notSupportedTooltip")
		end
		if SetFontScale then
			SetFontScale(value.code == "ja" and 0.93 or 1.0)
		end
	end)
	controls.languageLabel = new("LabelControl", { "RIGHT", controls.language, "LEFT" }, { defaultLabelSpacingPx, 0, 0, 16 * s }, "^7" .. i18n.t("options.language"))
	controls.language:SelByValue(self.language, "code")

	nextRow()
	controls.connectionProtocol = new("DropDownControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 100 * s, 18 * s }, {
		{ label = "Auto", protocol = 0 },
		{ label = "IPv4", protocol = 1 },
		{ label = "IPv6", protocol = 2 },
	}, function(index, value)
		self.connectionProtocol = value.protocol
	end)
	controls.connectionProtocolLabel = new("LabelControl", { "RIGHT", controls.connectionProtocol, "LEFT" }, { defaultLabelSpacingPx, 0, 0, 16 * s }, "^7" .. i18n.t("options.app.connectionProtocol"))
	controls.connectionProtocol.tooltipText = i18n.t("options.app.tooltipConnectionProtocol")
	controls.connectionProtocol:SelByValue(launch.connectionProtocol, "protocol")

	nextRow()
	controls.proxyType = new("DropDownControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 80 * s, 18 * s }, {
		{ label = "HTTP", scheme = "http" },
		{ label = "SOCKS", scheme = "socks5" },
		{ label = "SOCKS5H", scheme = "socks5h" },
	})
	controls.proxyLabel = new("LabelControl", { "RIGHT", controls.proxyType, "LEFT" }, { defaultLabelSpacingPx, 0, 0, 16 * s }, "^7" .. i18n.t("options.app.proxyServer"))
	controls.proxyURL = new("EditControl", { "LEFT", controls.proxyType, "RIGHT" }, { 4 * s, 0, 206 * s, 18 * s })

	if launch.proxyURL then
		local scheme, url = launch.proxyURL:match("(%w+)://(.+)")
		controls.proxyType:SelByValue(scheme, "scheme")
		controls.proxyURL:SetText(url)
	end

	nextRow()
	controls.dpiScaleOverride = new("DropDownControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 150 * s, 18 * s }, {
		{ label = i18n.t("options.app.useSystemDefault"), percent = 0 },
		{ label = "100%", percent = 100 },
		{ label = "125%", percent = 125 },
		{ label = "150%", percent = 150 },
		{ label = "175%", percent = 175 },
		{ label = "200%", percent = 200 },
		{ label = "225%", percent = 225 },
		{ label = "250%", percent = 250 },
	}, function(index, value)
		self.dpiScaleOverridePercent = value.percent
		SetDPIScaleOverridePercent(value.percent)
	end)
	controls.dpiScaleOverrideLabel = new("LabelControl", { "RIGHT", controls.dpiScaleOverride, "LEFT" }, { defaultLabelSpacingPx, 0, 0, 16 * s }, "^7" .. i18n.t("options.app.uiScaling"))
	controls.dpiScaleOverride.tooltipText = i18n.t("options.app.tooltipDpiScale")
	controls.dpiScaleOverride:SelByValue(self.dpiScaleOverridePercent, "percent")

	nextRow()
	controls.buildPath = new("EditControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 290 * s, 18 * s })
	controls.buildPathLabel = new("LabelControl", { "RIGHT", controls.buildPath, "LEFT" }, { defaultLabelSpacingPx, 0, 0, 16 * s }, "^7" .. i18n.t("options.app.buildSavePath"))
	if self.buildPath ~= self.defaultBuildPath then
		controls.buildPath:SetText(self.buildPath)
	end
	controls.buildPath.tooltipText = i18n.t("options.app.tooltipBuildPath")..self.defaultBuildPath.."'"

	nextRow()
	controls.nodePowerTheme = new("DropDownControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 100 * s, 18 * s }, {
		{ label = i18n.t("options.app.nodePowerRedBlue"), theme = "RED/BLUE" },
		{ label = i18n.t("options.app.nodePowerRedGreen"), theme = "RED/GREEN" },
		{ label = i18n.t("options.app.nodePowerGreenBlue"), theme = "GREEN/BLUE" },
	}, function(index, value)
		self.nodePowerTheme = value.theme
	end)
	controls.nodePowerThemeLabel = new("LabelControl", { "RIGHT", controls.nodePowerTheme, "LEFT" }, { defaultLabelSpacingPx, 0, 0, 16 * s }, "^7" .. i18n.t("options.app.nodePowerColours"))
	controls.nodePowerTheme.tooltipText = i18n.t("options.app.tooltipNodePowerTheme")
	controls.nodePowerTheme:SelByValue(self.nodePowerTheme, "theme")

	nextRow()
	controls.colorPositive = new("EditControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 100 * s, 18 * s }, tostring(self.colorPositive:gsub('^(^)', '0')), nil, nil, 8, function(buf)
		local match = string.match(buf, "0x%x+")
		if match and #match == 8 then
			updateColorCode("POSITIVE", buf)
			self.colorPositive = buf
		end
	end)
	controls.colorPositiveLabel = new("LabelControl", { "RIGHT", controls.colorPositive, "LEFT" }, { defaultLabelSpacingPx, 0, 0, 16 * s }, "^7" .. i18n.t("options.app.colorPositive"))
	controls.colorPositive.tooltipText = i18n.t("options.app.tooltipColorPrefix") .. i18n.t("options.app.tooltipColorPositiveDesc") .. i18n.t("options.app.tooltipColorFormat") .. tostring(defaultColorCodes.POSITIVE:gsub('^(^)', '0')) .. i18n.t("options.app.tooltipColorReload")

	nextRow()
	controls.colorNegative = new("EditControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 100 * s, 18 * s }, tostring(self.colorNegative:gsub('^(^)', '0')), nil, nil, 8, function(buf)
		local match = string.match(buf, "0x%x+")
		if match and #match == 8 then
			updateColorCode("NEGATIVE", buf)
			self.colorNegative = buf
		end
	end)
	controls.colorNegativeLabel = new("LabelControl", { "RIGHT", controls.colorNegative, "LEFT" }, { defaultLabelSpacingPx, 0, 0, 16 * s }, "^7" .. i18n.t("options.app.colorNegative"))
	controls.colorNegative.tooltipText = i18n.t("options.app.tooltipColorPrefix") .. i18n.t("options.app.tooltipColorNegativeDesc") .. i18n.t("options.app.tooltipColorFormat") .. tostring(defaultColorCodes.NEGATIVE:gsub('^(^)', '0')) .. i18n.t("options.app.tooltipColorReload")

	nextRow()

	controls.colorHighlight = new("EditControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 100 * s, 18 * s }, tostring(self.colorHighlight:gsub('^(^)', '0')), nil, nil, 8, function(buf)
		local match = string.match(buf, "0x%x+")
		if match and #match == 8 then
			updateColorCode("HIGHLIGHT", buf)
			self.colorHighlight = buf
		end
	end)
	controls.colorHighlightLabel = new("LabelControl", { "RIGHT", controls.colorHighlight, "LEFT" }, { defaultLabelSpacingPx, 0, 0, 16 * s }, "^7" .. i18n.t("options.app.colorHighlight"))
	controls.colorHighlight.tooltipText = i18n.t("options.app.tooltipColorPrefix") .. i18n.t("options.app.tooltipColorHighlightDesc") .. i18n.t("options.app.tooltipColorFormat") .. tostring(defaultColorCodes.HIGHLIGHT:gsub('^(^)', '0')) .. i18n.t("options.app.tooltipColorReload")

	nextRow()
	controls.betaTest = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 20 * s }, "^7" .. i18n.t("options.app.betaTest"), function(state)
		self.betaTest = state
	end)

	nextRow()
	controls.edgeSearchHighlight = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 20 * s}, "^7" .. i18n.t("options.build.edgeSearchHighlight"), function(state)
		self.edgeSearchHighlight = state
	end)

	nextRow()
	controls.showPublicBuilds = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 20 * s }, "^7" .. i18n.t("options.build.showPublicBuilds"), function(state)
		self.showPublicBuilds = state
	end)

	nextRow()
	controls.showFlavourText = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 20 * s }, "^7" .. i18n.t("options.build.showFlavourText"), function(state)
		self.showFlavourText = state
	end)
	controls.showFlavourText.tooltipText = i18n.t("options.build.tooltipFlavourText")

	nextRow()
	controls.showAnimations = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 20 * s }, "^7" .. i18n.t("options.build.showAnimations"), function(state)
		self.showAnimations = state
	end)

	nextRow()
	controls.showAllItemAffixes = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 20 * s }, "^7" .. i18n.t("options.build.showAllItemAffixes"), function(state)
		self.showAllItemAffixes = state
	end)
	controls.showAllItemAffixes.tooltipText = i18n.t("options.build.tooltipShowAllAffixes")

	nextRow()
	drawSectionHeader("build", i18n.t("options.build.header"))

	controls.showThousandsSeparators = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT"}, { defaultLabelPlacementX, currentY, 20 * s }, "^7" .. i18n.t("options.build.showThousandsSeparators"), function(state)
	self.showThousandsSeparators = state
	end)
	controls.showThousandsSeparators.state = self.showThousandsSeparators

	nextRow()
	controls.thousandsSeparator = new("EditControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 30 * s, 20 * s }, self.thousandsSeparator, nil, "%w", 1, function(buf)
		self.thousandsSeparator = buf
	end)
	controls.thousandsSeparatorLabel = new("LabelControl", { "RIGHT", controls.thousandsSeparator, "LEFT" }, { defaultLabelSpacingPx, 0, 0, 16 * s }, "^7" .. i18n.t("options.build.thousandsSeparator"))

	nextRow()
	controls.decimalSeparator = new("EditControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 30 * s, 20 * s }, self.decimalSeparator, nil, "%w", 1, function(buf)
		self.decimalSeparator = buf
	end)
	controls.decimalSeparatorLabel = new("LabelControl", { "RIGHT", controls.decimalSeparator, "LEFT" }, { defaultLabelSpacingPx, 0, 0, 16 * s }, "^7" .. i18n.t("options.build.decimalSeparator"))

	nextRow()
	controls.titlebarName = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 20 * s }, "^7" .. i18n.t("options.build.showTitlebarName"), function(state)
		self.showTitlebarName = state
	end)

	nextRow()
	controls.defaultGemQuality = new("EditControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 80 * s, 20 * s }, self.defaultGemQuality, nil, "%D", 2, function(gemQuality)
		self.defaultGemQuality = m_min(tonumber(gemQuality) or 0, 23)
	end)
	controls.defaultGemQuality.tooltipText = i18n.t("options.build.tooltipGemQuality")
	controls.defaultGemQualityLabel = new("LabelControl", { "RIGHT", controls.defaultGemQuality, "LEFT" }, { defaultLabelSpacingPx, 0, 0, 16 * s }, "^7" .. i18n.t("options.build.defaultGemQuality"))

	nextRow()
	controls.defaultCharLevel = new("EditControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 80 * s, 20 * s }, self.defaultCharLevel, nil, "%D", 3, function(charLevel)
		self.defaultCharLevel = m_min(m_max(tonumber(charLevel) or 1, 1), 100)
	end)
	controls.defaultCharLevel.tooltipText = i18n.t("options.build.tooltipCharLevel")
	controls.defaultCharLevelLabel = new("LabelControl", { "RIGHT", controls.defaultCharLevel, "LEFT" }, { defaultLabelSpacingPx, 0, 0, 16 * s }, "^7" .. i18n.t("options.build.defaultCharLevel"))

	nextRow()
	controls.defaultItemAffixQualitySlider = new("SliderControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 200 * s, 20 * s }, function(value)
		self.defaultItemAffixQuality = round(value, 2)
		controls.defaultItemAffixQualityValue.label = (self.defaultItemAffixQuality * 100) .. "%"
	end)
	controls.defaultItemAffixQualityLabel = new("LabelControl", { "RIGHT", controls.defaultItemAffixQualitySlider, "LEFT" }, { defaultLabelSpacingPx, 0, 0, 16 * s }, "^7" .. i18n.t("options.build.defaultItemAffixQuality"))
	controls.defaultItemAffixQualityValue = new("LabelControl", { "LEFT", controls.defaultItemAffixQualitySlider, "RIGHT" }, { -defaultLabelSpacingPx, 0, 92 * s, 16 * s }, "50%")
	controls.defaultItemAffixQualitySlider.val = self.defaultItemAffixQuality
	controls.defaultItemAffixQualityValue.label = (self.defaultItemAffixQuality * 100) .. "%"

	nextRow()
	controls.showWarnings = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 20 * s }, "^7" .. i18n.t("options.build.showWarnings"), function(state)
		self.showWarnings = state
	end)
	controls.showWarnings.state = self.showWarnings

	nextRow()
	controls.slotOnlyTooltips = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 20 * s }, "^7" .. i18n.t("options.build.slotOnlyTooltips"), function(state)
		self.slotOnlyTooltips = state
	end)
	controls.slotOnlyTooltips.state = self.slotOnlyTooltips

	nextRow()
	controls.notSupportedModTooltips = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 20 * s }, "^7" .. i18n.t("options.build.notSupportedModTooltips"), function(state)
		self.notSupportedModTooltips = state
	end)
	controls.notSupportedModTooltips.tooltipText = i18n.t("options.build.tooltipNotSupportedMod")
	controls.notSupportedModTooltips.state = self.notSupportedModTooltips

	nextRow()
	controls.invertSliderScrollDirection = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 20 * s }, "^7" .. i18n.t("options.build.invertSliderScroll"), function(state)
		self.invertSliderScrollDirection = state
	end)
	controls.invertSliderScrollDirection.tooltipText = i18n.t("options.build.tooltipInvertSlider")
	controls.invertSliderScrollDirection.state = self.invertSliderScrollDirection

	if launch.devMode then
		nextRow()
		controls.disableDevAutoSave = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT" }, { defaultLabelPlacementX, currentY, 20 * s }, "^7" .. i18n.t("options.app.disableDevAutoSave"), function(state)
			self.disableDevAutoSave = state
		end)
		controls.disableDevAutoSave.tooltipText = i18n.t("options.app.tooltipDevAutoSave")
		controls.disableDevAutoSave.state = self.disableDevAutoSave
	end

	controls.betaTest.state = self.betaTest
	controls.edgeSearchHighlight.state = self.edgeSearchHighlight
	controls.titlebarName.state = self.showTitlebarName
	controls.showPublicBuilds.state = self.showPublicBuilds
	controls.showFlavourText.state = self.showFlavourText
	controls.showAnimations.state = self.showAnimations
	controls.showAllItemAffixes.state = self.showAllItemAffixes
	local initialLanguage = self.language
	local initialNodePowerTheme = self.nodePowerTheme
	local initialColorPositive = self.colorPositive
	local initialColorNegative = self.colorNegative
	local initialColorHighlight = self.colorHighlight
	local initialThousandsSeparatorDisplay = self.showThousandsSeparators
	local initialTitlebarName = self.showTitlebarName
	local initialThousandsSeparator = self.thousandsSeparator
	local initialDecimalSeparator = self.decimalSeparator
	local initialBetaTest = self.betaTest
	local initialEdgeSearchHighlight = self.edgeSearchHighlight
	local initialDefaultGemQuality = self.defaultGemQuality or 0
	local initialDefaultCharLevel = self.defaultCharLevel or 1
	local initialDefaultItemAffixQuality = self.defaultItemAffixQuality or 0.5
	local initialShowWarnings = self.showWarnings
	local initialSlotOnlyTooltips = self.slotOnlyTooltips
	local initialNotSupportedModTooltips = self.notSupportedModTooltips
	local initialInvertSliderScrollDirection = self.invertSliderScrollDirection
	local initialDisableDevAutoSave = self.disableDevAutoSave
	local initialShowPublicBuilds = self.showPublicBuilds
	local initialShowFlavourText = self.showFlavourText
	local initialShowAnimations = self.showAnimations
	local initialShowAllItemAffixes = self.showAllItemAffixes
	local initialDpiScaleOverridePercent = self.dpiScaleOverridePercent

	-- last line with buttons has more spacing
	nextRow(1.5)

	controls.save = new("ButtonControl", nil, {-45, currentY, 80, 20}, i18n.t("options.save"), function()
		launch.connectionProtocol = tonumber(self.connectionProtocol)
		if controls.proxyURL.buf:match("%w") then
			launch.proxyURL = controls.proxyType.list[controls.proxyType.selIndex].scheme .. "://" .. controls.proxyURL.buf
		else
			launch.proxyURL = nil
		end
		if controls.buildPath.buf:match("%S") then
			self.buildPath = controls.buildPath.buf
			if not self.buildPath:match("[\\/]$") then
				self.buildPath = self.buildPath .. "/"
			end
		else
			self.buildPath = self.defaultBuildPath
		end
		if self.mode == "LIST" then
			self.modes.LIST:BuildList()
		end
		if not launch.devMode then
			main:SetManifestBranch(self.betaTest and "beta" or "master")
		end
		SetDPIScaleOverridePercent(self.dpiScaleOverridePercent)
		if SwitchFontFile then
			SwitchFontFile(self.language)
		end
		main:ClosePopup()
		main:SaveSettings()
	end)
	controls.cancel = new("ButtonControl", nil, {45, currentY, 80, 20}, i18n.t("options.cancel"), function()
		self.language = initialLanguage
		if i18n and i18n.setLocale then
			i18n.setLocale(self.language)
			self.notSupportedTooltipText = i18n.t("general.notSupportedTooltip")
		end
		if SetFontScale then
			SetFontScale(self.language == "ja" and 0.93 or 1.0)
		end
		self.nodePowerTheme = initialNodePowerTheme
		self.colorPositive = initialColorPositive
		updateColorCode("POSITIVE", self.colorPositive)
		self.colorNegative = initialColorNegative
		updateColorCode("NEGATIVE", self.colorNegative)
		self.colorHighlight = initialColorHighlight
		updateColorCode("HIGHLIGHT", self.colorHighlight)
		self.showThousandsSeparators = initialThousandsSeparatorDisplay
		self.thousandsSeparator = initialThousandsSeparator
		self.decimalSeparator = initialDecimalSeparator
		self.showTitlebarName = initialTitlebarName
		self.betaTest = initialBetaTest
		self.edgeSearchHighlight = initialEdgeSearchHighlight
		self.defaultGemQuality = initialDefaultGemQuality
		self.defaultCharLevel = initialDefaultCharLevel
		self.defaultItemAffixQuality = initialDefaultItemAffixQuality
		self.showWarnings = initialShowWarnings
		self.slotOnlyTooltips = initialSlotOnlyTooltips
		self.notSupportedModTooltips = initialNotSupportedModTooltips
		self.invertSliderScrollDirection = initialInvertSliderScrollDirection
		self.disableDevAutoSave = initialDisableDevAutoSave
		self.showPublicBuilds = initialShowPublicBuilds
		self.showFlavourText = initialShowFlavourText
		self.showAnimations = initialShowAnimations
		self.showAllItemAffixes = initialShowAllItemAffixes
		self.dpiScaleOverridePercent = initialDpiScaleOverridePercent
		SetDPIScaleOverridePercent(self.dpiScaleOverridePercent)
		main:ClosePopup()
	end)
	nextRow(1.5)
	self:OpenPopup(popupWidth, currentY, i18n.t("options.title"), controls, "save", nil, "cancel")
end

function main:SetManifestBranch(branchName)
	local xml = require("xml")
	local manifestLocation = "manifest.xml"
	local localManXML = xml.LoadXMLFile(manifestLocation)
	if not localManXML then
		manifestLocation = "../manifest.xml"
		localManXML = xml.LoadXMLFile(manifestLocation)
	end
	if localManXML and localManXML[1].elem == "PoBVersion" then
		for _, node in ipairs(localManXML[1]) do
			if type(node) == "table" then
				if node.elem == "Version" then
					node.attrib.branch = branchName
				end
			end
		end
	end
	xml.SaveXMLFile(localManXML[1], manifestLocation)
end

function main:OpenUpdatePopup()
	local s = self.screenScale or 1
	local changeList = { }
	local changelogName = launch.devMode and "../changelog.txt" or "changelog.txt"
	local changelogFile = io.open(changelogName, "r")
	if changelogFile then
		changelogFile:close()
		for line in io.lines(changelogName) do
			local ver, date = line:match("^VERSION%[(.+)%]%[(.+)%]$")
			if ver then
				if ver == launch.versionNumber then
					break
				end
				if #changeList > 0 then
					t_insert(changeList, { height = 12 * s })
				end
				t_insert(changeList, { height = 20 * s, "^7Version "..ver.." ("..date..")" })
			else
				t_insert(changeList, { height = 14 * s, "^7"..line })
			end
		end
	end
	local controls = { }
	controls.changeLog = new("TextListControl", nil, {0, 20 * s, 780 * s, 542 * s}, nil, changeList)
	controls.update = new("ButtonControl", nil, {-45 * s, 570 * s, 80 * s, 20 * s}, i18n.t("general.update"), function()
		self:ClosePopup()
		local ret = self:CallMode("CanExit", "UPDATE")
		if ret == nil or ret == true then
			launch:ApplyUpdate(launch.updateAvailable)
		end
	end)
	controls.cancel = new("ButtonControl", nil, {45 * s, 570 * s, 80 * s, 20 * s}, i18n.t("general.cancel"), function()
		self:ClosePopup()
	end)
	self:OpenPopup(800 * s, 600 * s, i18n.t("general.updateAvailable"), controls)
end

function main:OpenAboutPopup(helpSectionIndex)
	local s = self.screenScale or 1
	local textSize, subTitleSize, titleSize, popupWidth = 16 * s, 20 * s, 24 * s, 810 * s
	local changeList = { }
	local changeVersionHeights = { }
	local changelogName = launch.devMode and "../changelog.txt" or "changelog.txt"
	local changelogFile = io.open(changelogName, "r")
	if changelogFile then
		changelogFile:close()
		for line in io.lines(changelogName) do
			local ver, date = line:match("^VERSION%[(.+)%]%[(.+)%]$")
			if ver then
				if #changeList > 0 then
					t_insert(changeList, { height = textSize / 2 })
				end
				t_insert(changeVersionHeights, #changeList * textSize)
				t_insert(changeList, { height = titleSize, "^7Version "..ver.." ("..date..")" })
			elseif line:match("^---") then
				t_insert(changeList, { height = subTitleSize, "^7"..line })
			else
				t_insert(changeList, { height = textSize, "^7"..line })
			end
		end
	end
	local helpList = { }
	local helpSections = { }
	local helpSectionHeights = { }
	do
		local helpName = launch.devMode and "../help.txt" or "help.txt"
		local helpFile = io.open(helpName, "r")
		if helpFile then
			helpFile:close()
			for line in io.lines(helpName) do
				local title = line:match("^---%[(.+)%]$")
				if title then
					if #helpList > 0 then
						t_insert(helpList, { height = textSize / 2 })
					end
					t_insert(helpSections, { title = title, height = #helpList })
					t_insert(helpList, { height = titleSize, "^7"..title.." ("..#helpSections..")" })
				else
					local dev = line:match("^DEV%[(.+)%]$")
					if not ( dev and not launch.devMode ) then
						line = (dev or line)
						local outdent, indent = line:match("(.*)\t+(.*)")
						if outdent then
							local indentLines = self:WrapString(indent, textSize, popupWidth - 190)
							if #indentLines > 1 then
								for i, indentLine in ipairs(indentLines) do
									t_insert(helpList, { height = textSize, (i == 1 and outdent or " "), (dev and "^x8888FF" or "^7")..indentLine })
								end
							else
								t_insert(helpList, { height = textSize, (dev and "^x8888FF" or "^7")..outdent, (dev and "^x8888FF" or "^7")..indent })
							end
						else
							local Lines = self:WrapString(line, textSize, popupWidth - 135)
							for i, line2 in ipairs(Lines) do
								t_insert(helpList, { height = textSize, (dev and "^x8888FF" or "^7")..(i > 1 and "    " or "")..line2 })
							end
						end
					end
				end
			end
			local contentsDone = false
			for sectionIndex, sectionValues in ipairs(helpSections) do
				if sectionValues.title == "Contents" then
					t_insert(helpList, (sectionValues.height + sectionIndex), { height = textSize, "^7 "})
					for i, sectionValuesInner in ipairs(helpSections) do
						t_insert(helpList, (sectionValues.height + i + sectionIndex), { height = textSize, "^7"..tostring(i)..". "..sectionValuesInner.title })
					end
				end
				helpSections[sectionIndex].height = helpSections[sectionIndex].height + (contentsDone and (#helpSections + 1) or 0)
				helpSectionHeights[sectionIndex] = helpSections[sectionIndex].height * textSize
				if sectionValues.title == "Contents" then
					contentsDone = true
				end
			end
			helpSections.total = #helpList + #helpSections + 1
		end
	end
	if helpSectionIndex and not helpSections[helpSectionIndex] then
		local newIndex = 1
		for sectionIndex, sectionValues in ipairs(helpSections) do
			if sectionValues.title:lower() == helpSectionIndex then
				newIndex = sectionIndex
				break
			end
		end
		helpSectionIndex = newIndex
	end
	local controls = { }
	controls.close = new("ButtonControl", {"TOPRIGHT",nil,"TOPRIGHT"}, {-10 * s, 10 * s, 50 * s, 20 * s}, i18n.t("general.close"), function()
		self:ClosePopup()
	end)
	controls.version = new("LabelControl", nil, {0, 20 * s, 0, 18 * s}, i18n.t("general.aboutVersion")..launch.versionNumber)
	controls.forum = new("LabelControl", nil, {0, 40 * s, 0, 18 * s}, i18n.t("general.aboutCredit"))
	controls.poe2db = new("LabelControl", nil, {0, 56 * s, 0, 14 * s}, i18n.t("general.aboutCreditPoe2db"))
	controls.github = new("ButtonControl", nil, {0, 78 * s, 438 * s, 18 * s}, "^7" .. i18n.t("general.githubPage") .. " ^x4040FFhttps://github.com/kokagex/PoB2-for-macOS", function(control)
		OpenURL("https://github.com/kokagex/PoB2-for-macOS")
	end)
	controls.verLabel = new("ButtonControl", {"TOPLEFT", nil, "TOPLEFT"}, {10 * s, 102 * s, 100 * s, 18 * s}, "^7" .. i18n.t("general.versionHistory"), function()
		controls.changelog.list = changeList
		controls.changelog.sectionHeights = changeVersionHeights
	end)
	controls.helpLabel = new("ButtonControl", {"TOPRIGHT", nil, "TOPRIGHT"}, {-10 * s, 102 * s, 40 * s, 18 * s}, "^7" .. i18n.t("general.help"), function()
		controls.changelog.list = helpList
		controls.changelog.sectionHeights = helpSectionHeights
	end)
	controls.changelog = new("TextListControl", nil, {0, 120 * s, popupWidth - 20 * s, 498 * s}, {{ x = 1, align = "LEFT" }, { x = 135 * s, align = "LEFT" }}, helpSectionIndex and helpList or changeList, helpSectionIndex and helpSectionHeights or changeVersionHeights)
	if helpSectionIndex then
		controls.changelog.controls.scrollBar.offset = helpSections[helpSectionIndex].height * textSize
	end
	self:OpenPopup(popupWidth, 628 * s, i18n.t("general.about"), controls)
end

function main:DrawBackground(viewPort)
	SetDrawLayer(nil, -100)
	SetDrawColor(0.5, 0.5, 0.5)
	if self.tree[latestTreeVersion].assets.Background2 then
		DrawImage(self.tree[latestTreeVersion].assets.Background2.handle, viewPort.x, viewPort.y, viewPort.width, viewPort.height, 0, 0, viewPort.width / 100, viewPort.height / 100)
	elseif self.tree[latestTreeVersion].assets.Background1 then
		DrawImage(self.tree[latestTreeVersion].assets.Background1.handle, viewPort.x, viewPort.y, viewPort.width, viewPort.height, 0, 0, viewPort.width / 100, viewPort.height / 100)
	end
	SetDrawLayer(nil, 0)
end

function main:DrawArrow(x, y, width, height, dir)
	local x1 = x - width / 2
	local x2 = x + width / 2
	local xMid = (x1 + x2) / 2
	local y1 = y - height / 2
	local y2 = y + height / 2
	local yMid = (y1 + y2) / 2
	if dir == "UP" then
		DrawImageQuad(nil, xMid, y1, xMid, y1, x2, y2, x1, y2)
	elseif dir == "RIGHT" then
		DrawImageQuad(nil, x1, y1, x2, yMid, x2, yMid, x1, y2)
	elseif dir == "DOWN" then
		DrawImageQuad(nil, x1, y1, x2, y1, xMid, y2, xMid, y2)
	elseif dir == "LEFT" then
		DrawImageQuad(nil, x1, yMid, x2, y1, x2, y2, x1, yMid)
	end
end

function main:DrawCheckMark(x, y, size)
	size = size / 0.8
	x = x - size / 2
	y = y - size / 2
	DrawImageQuad(nil, x + size * 0.15, y + size * 0.50, x + size * 0.30, y + size * 0.45, x + size * 0.50, y + size * 0.80, x + size * 0.40, y + size * 0.90)
	DrawImageQuad(nil, x + size * 0.40, y + size * 0.90, x + size * 0.35, y + size * 0.75, x + size * 0.80, y + size * 0.10, x + size * 0.90, y + size * 0.20)
end

do
	local cos45 = m_cos(m_pi / 4)
	local cos35 = m_cos(m_pi * 0.195)
	local sin35 = m_sin(m_pi * 0.195)
	function main:WorldToScreen(x, y, z, width, height)
		-- World -> camera
		local cx = (x - y) * cos45
		local cy = -5.33 - (y + x) * cos45 * cos35 - z * sin35
		local cz = 122 + (y + x) * cos45 * sin35 - z * cos35
		-- Camera -> screen
		local sx = width * 0.5 + cx / cz * 1.27 * height
		local sy = height * 0.5 + cy / cz * 1.27 * height
		return round(sx), round(sy)
	end
end

function main:RenderCircle(x, y, width, height, oX, oY, radius)
	local minX = wipeTable(tempTable1)
	local maxX = wipeTable(tempTable2)
	local minY = height
	local maxY = 0
	for d = 0, 360, 0.15 do
		local r = d / 180 * m_pi
		local px, py = main:WorldToScreen(oX + m_sin(r) * radius, oY + m_cos(r) * radius, 0, width, height)
		if py >= 0 and py < height then
			px = m_min(width, m_max(0, px))
			minY = m_min(minY, py)
			maxY = m_max(maxY, py)
			minX[py] = m_min(minX[py] or px, px)
			maxX[py] = m_max(maxX[py] or px, px)
		end
	end
	for ly = minY, maxY do
		if minX[ly] then
			DrawImage(nil, x + minX[ly], y + ly, maxX[ly] - minX[ly] + 1, 1)
		end
	end
end

function main:RenderRing(x, y, width, height, oX, oY, radius, size)
	local lastX, lastY
	for d = 0, 360, 0.2 do
		local r = d / 180 * m_pi
		local px, py = main:WorldToScreen(oX + m_sin(r) * radius, oY + m_cos(r) * radius, 0, width, height)
		if px >= -size/2 and px < width + size/2 and py >= -size/2 and py < height + size/2 and (px ~= lastX or py ~= lastY) then
			DrawImage(nil, x + px - size/2, y + py, size, size)
			lastX, lastY = px, py
		end
	end
end

function main:StatColor(stat, base, limit)
	if limit and stat > limit then
		return colorCodes.NEGATIVE
	elseif base and stat ~= base then
		return colorCodes.MAGIC
	else
		return "^7"
	end
end

function main:MoveFolder(name, srcPath, dstPath)
	-- Create destination folder
	local res, msg = MakeDir(dstPath..name)
	if not res then
		self:OpenMessagePopup(i18n.t("general.error"), string.format(i18n.t("general.couldntMove"), name, dstPath, msg))
		return
	end

	-- Move subfolders
	local handle = NewFileSearch(srcPath..name.."/*", true)
	while handle do
		self:MoveFolder(handle:GetFileName(), srcPath..name.."/", dstPath..name.."/")
		if not handle:NextFile() then
			break
		end
	end

	-- Move files
	handle = NewFileSearch(srcPath..name.."/*")
	while handle do
		local fileName = handle:GetFileName()
		local srcName = srcPath..name.."/"..fileName
		local dstName = dstPath..name.."/"..fileName
		local res, msg = os.rename(srcName, dstName)
		if not res then
			self:OpenMessagePopup(i18n.t("general.error"), string.format(i18n.t("general.couldntMove"), srcName, dstName, msg))
			return
		end
		if not handle:NextFile() then
			break
		end
	end

	-- Remove source folder
	local res, msg = RemoveDir(srcPath..name)
	if not res then
		self:OpenMessagePopup(i18n.t("general.error"), string.format(i18n.t("general.couldntDelete"), dstPath..name, msg))
		return
	end
end

function main:CopyFolder(srcName, dstName)
	-- Create destination folder
	local res, msg = MakeDir(dstName)
	if not res then
		self:OpenMessagePopup(i18n.t("general.error"), string.format(i18n.t("general.couldntCopy"), srcName, dstName, msg))
		return
	end

	-- Copy subfolders
	local handle = NewFileSearch(srcName.."/*", true)
	while handle do
		local fileName = handle:GetFileName()
		self:CopyFolder(srcName.."/"..fileName, dstName.."/"..fileName)
		if not handle:NextFile() then
			break
		end
	end

	-- Copy files
	handle = NewFileSearch(srcName.."/*")
	while handle do
		local fileName = handle:GetFileName()
		local srcName = srcName.."/"..fileName
		local dstName = dstName.."/"..fileName
		local res, msg = copyFile(srcName, dstName)
		if not res then
			self:OpenMessagePopup(i18n.t("general.error"), string.format(i18n.t("general.couldntCopy"), srcName, dstName, msg))
			return
		end
		if not handle:NextFile() then
			break
		end
	end
end

function main:OpenPopup(width, height, title, controls, enterControl, defaultControl, escapeControl, scrollBarFunc, resizeFunc)
	local popup = new("PopupDialog", width, height, title, controls, enterControl, defaultControl, escapeControl, scrollBarFunc, resizeFunc)
	t_insert(self.popups, 1, popup)
	return popup
end

function main:ClosePopup()
	t_remove(self.popups, 1)
end

function main:OpenMessagePopup(title, msg)
	local controls = { }
	local numMsgLines = 0
	for line in string.gmatch(msg .. "\n", "([^\n]*)\n") do
		t_insert(controls, new("LabelControl", nil, {0, 20 + numMsgLines * 16, 0, 16}, line))
		numMsgLines = numMsgLines + 1
	end
	controls.close = new("ButtonControl", nil, {0, 40 + numMsgLines * 16, 80, 20}, i18n.t("general.ok"), function()
		main:ClosePopup()
	end)
	return self:OpenPopup(m_max(DrawStringWidth(16, "VAR", msg) + 30, 190), 70 + numMsgLines * 16, title, controls, "close")
end

function main:OpenConfirmPopup(title, msg, confirmLabel, onConfirm, extraLabel, onExtra)
	local controls = { }
	local numMsgLines = 0
	for line in string.gmatch(msg .. "\n", "([^\n]*)\n") do
		t_insert(controls, new("LabelControl", nil, {0, 20 + numMsgLines * 16, 0, 16}, line))
		numMsgLines = numMsgLines + 1
	end
	local confirmWidth = m_max(80, DrawStringWidth(16, "VAR", confirmLabel) + 10)
	
	if extraLabel and onExtra then
		-- Three button layout: Continue (left), Connect Path (center), Cancel (right)
		local extraWidth = m_max(80, DrawStringWidth(16, "VAR", extraLabel) + 10)
		local cancelWidth = 80
		local spacing = 10
		local totalWidth = confirmWidth + extraWidth + cancelWidth + (spacing * 2)
		local leftEdge = -totalWidth / 2
		local buttonY = 40 + numMsgLines * 16
		local function placeButton(width, label, onClick, isConfirm)
			local centerX = leftEdge + width / 2
			local ctrl = new("ButtonControl", nil, {centerX, buttonY, width, 20}, label, function()
				main:ClosePopup()
				onClick()
			end)
			if isConfirm then
				controls.confirm = ctrl
			else
				t_insert(controls, ctrl)
			end
			leftEdge = leftEdge + width + spacing
		end
		placeButton(confirmWidth, confirmLabel, onConfirm, true)
		placeButton(extraWidth, extraLabel, onExtra)
		placeButton(cancelWidth, i18n.t("general.cancel"), function() end)
		return self:OpenPopup(m_max(DrawStringWidth(16, "VAR", msg) + 30, totalWidth + 40), 70 + numMsgLines * 16, title, controls, "confirm")
	else
		-- Two button layout (original)
		controls.confirm = new("ButtonControl", nil, {-5 - m_ceil(confirmWidth/2), 40 + numMsgLines * 16, confirmWidth, 20}, confirmLabel, function()
			main:ClosePopup()
			onConfirm()
		end)
		t_insert(controls, new("ButtonControl", nil, {5 + m_ceil(confirmWidth/2), 40 + numMsgLines * 16, confirmWidth, 20}, i18n.t("general.cancel"), function()
			main:ClosePopup()
		end))
		return self:OpenPopup(m_max(DrawStringWidth(16, "VAR", msg) + 30, 190), 70 + numMsgLines * 16, title, controls, "confirm")
	end
end

function main:OpenNewFolderPopup(path, onClose)
	local controls = { }
	controls.label = new("LabelControl", nil, {0, 20, 0, 16}, "^7" .. i18n.t("general.enterFolderName"))
	controls.edit = new("EditControl", nil, {0, 40, 350, 20}, nil, nil, "\\/:%*%?\"<>|%c", 100, function(buf)
		controls.create.enabled = buf:match("%S")
	end)
	controls.create = new("ButtonControl", nil, {-45, 70, 80, 20}, i18n.t("general.create"), function()
		local newFolderName = controls.edit.buf
		local res, msg = MakeDir(path..newFolderName)
		if not res then
			main:OpenMessagePopup(i18n.t("general.error"), string.format(i18n.t("general.couldntCreate"), newFolderName, msg))
			return
		end
		if onClose then
			onClose(newFolderName)
		end
		main:ClosePopup()
	end)
	controls.create.enabled = false
	controls.cancel = new("ButtonControl", nil, {45, 70, 80, 20}, i18n.t("general.cancel"), function()
		if onClose then
			onClose()
		end
		main:ClosePopup()
	end)
	main:OpenPopup(370, 100, i18n.t("general.newFolderTitle"), controls, "create", "edit", "cancel")
end

-- Show an error popup if a file cannot be read due to cloud provider unavailability.
-- Help button opens a URL to PoB's GitHub wiki.
function main:OpenCloudErrorPopup(fileName)
	local provider, _, status = GetCloudProvider(fileName)
	ConPrintf('^1Error: file offline "%s" provider: "%s" status: "%s"', fileName or "?", provider, status)
	fileName = fileName and "\n\n^8'"..fileName.."'" or ""
	local version = "^8v"..launch.versionNumber..(launch.versionBranch and " "..launch.versionBranch or "")..(launch.devMode and " (dev)" or "")
	local title = i18n.t("general.cloudErrorTitle")
	provider = provider or "your cloud provider"
	local statusText = tostring(status) or "nil"
	local msg = i18n.t("general.cloudErrorCannotRead")..string.format(i18n.t("general.cloudErrorMakeSure"), provider, APP_NAME)..
		fileName..i18n.t("general.cloudErrorStatus")..statusText.."\n\n"..version
	local url = "https://github.com/PathOfBuildingCommunity/PathOfBuilding/wiki/CloudError"
	local controls = { }
	local numMsgLines = 0
	for line in string.gmatch(msg .. "\n", "([^\n]*)\n") do
		t_insert(controls, new("LabelControl", nil, {0, 20 + numMsgLines * 16, 0, 16}, line))
		numMsgLines = numMsgLines + 1
	end
	controls.help = new("ButtonControl", nil, {-55, 40 + numMsgLines * 16, 80, 20}, i18n.t("general.helpWeb"), function()
		OpenURL(url)
	end)
	controls.help.tooltipText = url
	controls.close = new("ButtonControl", nil, {55, 40 + numMsgLines * 16, 80, 20}, i18n.t("general.ok"), function()
		main:ClosePopup()
	end)
	return self:OpenPopup(m_max(DrawStringWidth(16, "VAR", msg) + 30, 190), 70 + numMsgLines * 16, title, controls, "close")
end

function main:SetWindowTitleSubtext(subtext)
	if not subtext or not self.showTitlebarName then
		SetWindowTitle(APP_NAME)
	else
		SetWindowTitle(subtext.." - "..APP_NAME)
	end
end

do
	local wrapTable = { }
	-- Check if string contains CJK characters (Hiragana, Katakana, Kanji, CJK Symbols)
	-- These are 3-byte UTF-8 sequences starting with bytes 0xE3-0xE9
	local function hasCJK(str)
		return str:find("[\227-\233][\128-\191][\128-\191]") ~= nil
	end
	-- Get UTF-8 character byte length from first byte
	local function utf8charLen(byte)
		if byte < 128 then return 1
		elseif byte < 224 then return 2
		elseif byte < 240 then return 3
		else return 4 end
	end
	function main:WrapString(str, height, width)
		wipeTable(wrapTable)
		if not hasCJK(str) then
			-- Original space-based wrapping for non-CJK text
			local lineStart = 1
			local lastSpace, lastBreak
			while true do
				local s, e = str:find("%s+", lastSpace)
				if not s then
					s = #str + 1
					e = #str + 1
				end
				if s > #str then
					t_insert(wrapTable, str:sub(lineStart, -1))
					break
				end
				lastBreak = s - 1
				lastSpace = e + 1
				if DrawStringWidth(height, "VAR", str:sub(lineStart, s - 1)) > width then
					t_insert(wrapTable, str:sub(lineStart, lastBreak))
					lineStart = lastSpace
				end
			end
		else
			-- CJK-aware wrapping: break at character boundaries
			local lineStart = 1
			local len = #str
			local pos = 1
			local lastBreakPos = nil
			local safetyLimit = len * 3
			local iter = 0
			while pos <= len do
				iter = iter + 1
				if iter > safetyLimit then break end
				local b = str:byte(pos)
				local cLen = utf8charLen(b)
				local nextPos = pos + cLen
				-- Check if current character is a valid break point
				-- CJK characters, spaces, and punctuation are valid break points
				if b == 32 or b >= 227 then -- space or CJK 3-byte start
					lastBreakPos = pos
				end
				-- Measure width of current line up to next character
				if nextPos <= len + 1 and DrawStringWidth(height, "VAR", str:sub(lineStart, nextPos - 1)) > width then
					if lastBreakPos and lastBreakPos > lineStart then
						-- Break at last valid break point
						if str:byte(lastBreakPos) == 32 then
							-- Break at space: don't include space in output
							t_insert(wrapTable, str:sub(lineStart, lastBreakPos - 1))
							lineStart = lastBreakPos + 1
						else
							-- Break before CJK character
							t_insert(wrapTable, str:sub(lineStart, lastBreakPos - 1))
							lineStart = lastBreakPos
						end
						lastBreakPos = nil
						-- Don't advance pos; re-measure from new lineStart
					elseif pos > lineStart then
						-- No break point found, force break before current char
						t_insert(wrapTable, str:sub(lineStart, pos - 1))
						lineStart = pos
						lastBreakPos = nil
					else
						-- Single character exceeds width, include it anyway
						t_insert(wrapTable, str:sub(lineStart, nextPos - 1))
						lineStart = nextPos
						pos = nextPos
						lastBreakPos = nil
					end
				else
					pos = nextPos
				end
			end
			-- Add remaining text
			if lineStart <= len then
				t_insert(wrapTable, str:sub(lineStart))
			end
		end
		return wrapTable
	end
end

return main

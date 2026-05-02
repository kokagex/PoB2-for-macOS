-- Path of Building
--
-- Class: Item DB
-- Item DB control.
--
local pairs = pairs
local ipairs = ipairs
local t_insert = table.insert
local m_max = math.max
local m_floor = math.floor


local ItemDBClass = newClass("ItemDBControl", "ListControl", function(self, anchor, rect, itemsTab, db, dbType)
	self.ListControl(anchor, rect, 16, "VERTICAL", false)
	self.itemsTab = itemsTab
	self.db = db
	self.dbType = dbType
	self.dragTargetList = { }
	self.sortControl = { 
		NAME = { key = "name", dir = "ASCEND", func = function(a,b) return a:gsub("^The ","") < b:gsub("^The ","") end },
		STAT = { key = "measuredPower", dir = "DESCEND" },
	}
	self.sortDropList = { }
	self.sortOrder = { }
	self.sortMode = "NAME"
	self.leaguesAndTypesLoaded = false
	self.leagueList = { i18n.t("items.filter.anyLeague"), i18n.t("items.filter.noLeague") }
	self.typeList = { i18n.t("items.filter.anyType"), i18n.t("items.filter.armour"), i18n.t("items.filter.jewellery"), i18n.t("items.filter.oneHandedMelee"), i18n.t("items.filter.twoHandedMelee") }
	local slotNames = { "Weapon 1", "Weapon 2", "Helmet", "Body Armour", "Gloves", "Boots", "Amulet", "Ring", "Belt", "Jewel" }
	self.slotList = { i18n.t("items.filter.anySlot") }
	for _, name in ipairs(slotNames) do
		table.insert(self.slotList, { label = i18n.lookup("items.slots", name) or name, slotName = name })
	end
	local baseY = dbType == "RARE" and -22 or -62
	self.controls.slot = new("DropDownControl", {"BOTTOMLEFT",self,"TOPLEFT"}, {0, baseY, 179, 18}, self.slotList, function(index, value)
		self.listBuildFlag = true
	end)
	self.controls.type = new("DropDownControl", {"LEFT",self.controls.slot,"RIGHT"}, {2, 0, 179, 18}, self.typeList, function(index, value)
		self.listBuildFlag = true
	end)
	if dbType == "UNIQUE" then
		self.controls.sort = new("DropDownControl", {"BOTTOMLEFT",self,"TOPLEFT"}, {0, baseY + 20, 179, 18}, self.sortDropList, function(index, value)
			self:SetSortMode(value.sortMode)
			self.listBuildFlag = true
		end)
		self.controls.league = new("DropDownControl", {"LEFT",self.controls.sort,"RIGHT"}, {2, 0, 179, 18}, self.leagueList, function(index, value)
			self.listBuildFlag = true
		end)
		self.controls.requirement = new("DropDownControl", {"LEFT",self.controls.sort,"BOTTOMLEFT"}, {0, 11, 179, 18}, { i18n.t("items.filter.anyRequirements"), i18n.t("items.filter.currentLevel"), i18n.t("items.filter.currentAttributes"), i18n.t("items.filter.currentUseable") }, function(index, value)
			self.listBuildFlag = true
		end)
		self.controls.obtainable = new("DropDownControl", {"LEFT",self.controls.requirement,"RIGHT"}, {2, 0, 179, 18}, { i18n.t("items.filter.obtainable"), i18n.t("items.filter.anySource"), i18n.t("items.filter.unobtainable"), i18n.t("items.filter.vendorRecipe"), i18n.t("items.filter.upgraded"), i18n.t("items.filter.bossItem"), i18n.t("items.filter.corruption")}, function(index, value)
			self.listBuildFlag = true
		end)
	end
	self.controls.search = new("EditControl", {"BOTTOMLEFT",self,"TOPLEFT"}, {0, -2, 258, 18}, "", "Search", "%c", 100, function()
		self.listBuildFlag = true
	end, nil, nil, true)
	self.controls.searchMode = new("DropDownControl", {"LEFT",self.controls.search,"RIGHT"}, {2, 0, 100, 18}, { i18n.t("items.filter.anywhere"), i18n.t("items.filter.names"), i18n.t("items.filter.modifiers") }, function(index, value)
		self.listBuildFlag = true
	end)
	self:BuildSortOrder()
	self.listBuildFlag = true
end)

function ItemDBClass:LoadLeaguesAndTypes()
	local leagueFlag = { }
	local typeFlag = { }
	for _, item in pairs(self.db.list) do
		if item.league then
			for leagueName in item.league:gmatch(" ?([%w ]+),?") do
				leagueFlag[leagueName] = true
			end
		end
		typeFlag[item.type] = true
	end
	for leagueName in pairsSortByKey(leagueFlag) do
		t_insert(self.leagueList, { label = i18n.lookup("items.leagueNames", leagueName) or leagueName, leagueName = leagueName })
	end
	for typeName in pairsSortByKey(typeFlag) do
		local translated = i18n.lookup("items.typeNames", typeName)
		t_insert(self.typeList, { label = translated or typeName, typeName = typeName })
	end
	self.leaguesAndTypesLoaded = true
end

function ItemDBClass:DoesItemMatchFilters(item)
	if self.controls.slot.selIndex > 1 then
		local primarySlot = item:GetPrimarySlot()
		local selSlot = self.slotList[self.controls.slot.selIndex]
		local slotName = type(selSlot) == "table" and selSlot.slotName or selSlot
		if primarySlot ~= slotName and primarySlot:gsub(" %d","") ~= slotName then
			return false
		end
	end
	local typeSel = self.controls.type.selIndex
	if typeSel > 1 then
		if typeSel == 2 then
			if not item.base.armour then
				return false
			end
		elseif typeSel == 3 then
			if not (item.type == "Amulet" or item.type == "Ring" or item.type == "Belt") then
				return false
			end
		elseif typeSel == 4 or typeSel == 5 then
			local weaponInfo = self.itemsTab.build.data.weaponTypeInfo[item.type]
			if not (weaponInfo and weaponInfo.melee and ((typeSel == 4 and weaponInfo.oneHand) or (typeSel == 5 and not weaponInfo.oneHand))) then 
				return false
			end
			if item.type == "Staff" then
				if item.base.subType ~= "Warstaff" then
					return false
				end
			end
		elseif item.type ~= (type(self.typeList[typeSel]) == "table" and self.typeList[typeSel].typeName or self.typeList[typeSel]) then
			return false
		end
	end
	if self.dbType == "UNIQUE" and self.controls.league.selIndex > 1 then
		if (self.controls.league.selIndex == 2 and item.league) or (self.controls.league.selIndex > 2 and (not item.league or not item.league:match((type(self.leagueList[self.controls.league.selIndex]) == "table" and self.leagueList[self.controls.league.selIndex].leagueName or self.leagueList[self.controls.league.selIndex])))) then
			return false
		end
	end
	if self.dbType == "UNIQUE" and self.controls.obtainable.selIndex ~= 2 then
		local source = item.source or ""
		local obtainable = not (source == "No longer obtainable" or (item.league and item.league == "Race Events"))
		if (self.controls.obtainable.selIndex == 1 and not obtainable) or (self.controls.obtainable.selIndex == 3 and obtainable) then
			return false
		elseif (self.controls.obtainable.selIndex == 4 and not (source == "Vendor Recipe")) then
			return false
		elseif (self.controls.obtainable.selIndex == 5 and not (string.match(source, "Upgraded from"))) then
			return false
		elseif (self.controls.obtainable.selIndex == 6 and not (string.match(source, "Drops from unique"))) then
			return false
		elseif (self.controls.obtainable.selIndex == 7 and not (string.match(source, "Vaal Orb"))) then
			return false
		end
	end
	if self.dbType == "UNIQUE" and self.controls.requirement.selIndex > 1 then
		if (self.controls.requirement.selIndex == 2 or self.controls.requirement.selIndex == 4) and item.requirements.level and item.requirements.level > self.itemsTab.build.characterLevel then
			return false
		end
		if self.controls.requirement.selIndex > 2 and item.requirements and (item.requirements.strMod > self.itemsTab.build.calcsTab.mainOutput.Str or item.requirements.dexMod > self.itemsTab.build.calcsTab.mainOutput.Dex or item.requirements.intMod > self.itemsTab.build.calcsTab.mainOutput.Int) then
			return false
		end
	end
	local searchStr = self.controls.search.buf:lower():gsub("[%-%.%+%[%]%$%^%%%?%*]", "%%%0")
	if searchStr:match("%S") then
		local found = false
		local mode = self.controls.searchMode.selIndex
		if mode == 1 or mode == 2 then
			local err, match = PCall(string.matchOrPattern, item.name:lower(), searchStr)
			if not err and match then
				found = true
			end
			if not found and i18n then
				local jName
				if item.title then
					local jTitle = i18n.lookup("uniqueNames", item.title)
					local cleanBase = item.baseName and item.baseName:gsub(" %(.+%)","") or ""
					local jBase = i18n.lookup("baseNames", cleanBase)
					if jTitle or jBase then
						jName = (jTitle or item.title) .. ", " .. (jBase or cleanBase)
					end
				elseif item.baseName then
					local cleanBase = item.baseName:gsub(" %(.+%)","")
					local jBase = i18n.lookup("baseNames", cleanBase)
					if jBase then
						jName = item.namePrefix .. jBase .. item.nameSuffix
					end
				end
				if jName then
					local err2, match2 = PCall(string.matchOrPattern, jName:lower(), searchStr)
					if not err2 and match2 then
						found = true
					end
				end
			end
		end
		if mode == 1 or mode == 3 then
			for _, line in pairs(item.enchantModLines) do
				local err, match = PCall(string.matchOrPattern, line.line:lower(), searchStr)
				if not err and match then
					found = true
					break
				end
			end
			for _, line in pairs(item.runeModLines) do
				local err, match = PCall(string.matchOrPattern, line.line:lower(), searchStr)
				if not err and match then
					found = true
					break
				end
			end
			for _, line in pairs(item.implicitModLines) do
				local err, match = PCall(string.matchOrPattern, line.line:lower(), searchStr)
				if not err and match then
					found = true
					break
				end
			end
			for _, line in pairs(item.explicitModLines) do
				local err, match = PCall(string.matchOrPattern, line.line:lower(), searchStr)
				if not err and match then
					found = true
					break
				end
			end
			if not found then
				searchStr = searchStr:gsub(" ","")
				for i, mod in ipairs(item.baseModList) do
					local err, match = PCall(string.matchOrPattern, mod.name:lower(), searchStr)
					if not err and match then
						found = true
						break
					end
				end
			end
		end
		if not found then
			return false
		end
	end
	return true
end

function ItemDBClass:SetSortMode(sortMode)
	self.sortMode = sortMode
	self:BuildSortOrder()
	self.listBuildFlag = true
end

function ItemDBClass:BuildSortOrder()
	wipeTable(self.sortDropList)
	for id,stat in pairs(data.powerStatList) do
		if not stat.ignoreForItems then
			t_insert(self.sortDropList, {
				label=i18n.t("items.sort.prefix")..(i18n.lookup("items.sort.stats", stat.label) or stat.label),
				sortMode=stat.itemField or stat.stat,
				itemField=stat.itemField,
				stat=stat.stat,
				transform=stat.transform,
			})
		end
	end
	wipeTable(self.sortOrder)
	if self.controls.sort then
		self.controls.sort:CheckDroppedWidth(true)
		self.controls.sort.selIndex = 1
		self.controls.sort:SelByValue(self.sortMode, "sortMode")
		self.sortDetail = self.controls.sort.list[self.controls.sort.selIndex]
	end
	if self.sortDetail and self.sortDetail.stat then
		t_insert(self.sortOrder, self.sortControl.STAT)
	end
	t_insert(self.sortOrder, self.sortControl.NAME)
end

function ItemDBClass:ListBuilder()
	local list = { }
	for id, item in pairs(self.db.list) do
		if self:DoesItemMatchFilters(item) then
			t_insert(list, item)
		end
	end

	if self.sortDetail and self.sortDetail.stat then -- stat-based
		local useFullDPS = self.sortDetail.stat == "FullDPS"
		local start = GetTime()
		local calcFunc, calcBase = self.itemsTab.build.calcsTab:GetMiscCalculator(self.build)
		for itemIndex, item in ipairs(list) do
			item.measuredPower = 0
			for slotName, slot in pairs(self.itemsTab.slots) do
				if self.itemsTab:IsItemValidForSlot(item, slotName) and not slot.inactive and (not slot.weaponSet or slot.weaponSet == (self.itemsTab.activeItemSet.useSecondWeaponSet and 2 or 1)) then
					local output = calcFunc(item.base.flask and { toggleFlask = item } or item.base.charm and { toggleCharm = item } or { repSlotName = slotName, repItem = item }, useFullDPS)
					local measuredPower = output.Minion and output.Minion[self.sortMode] or output[self.sortMode] or 0
					if self.sortDetail.transform then
						measuredPower = self.sortDetail.transform(measuredPower)
					end
					item.measuredPower = m_max(item.measuredPower, measuredPower)
				end
			end
			local now = GetTime()
			if now - start > 50 then
				self.defaultText = "^7" .. i18n.t("items.filter.sorting", {pct = m_floor(itemIndex/#list*100)})
				coroutine.yield()
				start = now
			end
		end
	end

	table.sort(list, function(a, b)
		for _, data in ipairs(self.sortOrder) do
			local aVal = a[data.key]
			local bVal = b[data.key]
			if aVal ~= bVal then
				if data.dir == "DESCEND" then
					if data.func then
						return data.func(bVal, aVal)
					else
						return bVal < aVal
					end
				else
					if data.func then
						return data.func(aVal, bVal)
					else
						return aVal < bVal
					end
				end
			end
		end
	end)

	self.list = list
	self.defaultText = "^7" .. i18n.t("items.filter.noItemsFound")
end

function ItemDBClass:Draw(viewPort)
	if self.itemsTab.build.outputRevision ~= self.listOutputRevision then
		self.listBuildFlag = true
	end
	if self.listBuildFlag then
		self.listBuildFlag = false
		wipeTable(self.list)
		self.listBuilder = coroutine.create(self.ListBuilder)
		self.listOutputRevision = self.itemsTab.build.outputRevision
	end
	if self.listBuilder and not self.db.loading then
		local res, errMsg = coroutine.resume(self.listBuilder, self)
		if launch.devMode and not res then
			error(errMsg)
		end
		if coroutine.status(self.listBuilder) == "dead" then
			self.listBuilder = nil
		end
	end
	if self.db.loading then
		self.defaultText = "^7" .. i18n.t("items.filter.loading")
	elseif not self.leaguesAndTypesLoaded then
		self:LoadLeaguesAndTypes()
	end
	self.ListControl.Draw(self, viewPort)
end

function ItemDBClass:GetRowValue(column, index, item)
	if column == 1 then
		local displayName = item.name
		if item.title and i18n then
			local jTitle = i18n.lookup("uniqueNames", item.title)
			local cleanBase = item.baseName and item.baseName:gsub(" %(.+%)","") or ""
			local jBase = i18n.lookup("baseNames", cleanBase)
			if jTitle or jBase then
				displayName = (jTitle or item.title) .. ", " .. (jBase or cleanBase)
			end
		elseif not item.title and item.baseName and i18n then
			local cleanBase = item.baseName:gsub(" %(.+%)","")
			local jBase = i18n.lookup("baseNames", cleanBase)
			if jBase then
				displayName = item.namePrefix .. jBase .. item.nameSuffix
			end
		end
		return colorCodes[item.rarity] .. displayName
	end
end

function ItemDBClass:AddValueTooltip(tooltip, index, item)
	if main.popups[1] then
		tooltip:Clear()
		return
	end
	if tooltip:CheckForUpdate(item, IsKeyDown("SHIFT"), launch.devModeAlt, self.itemsTab.build.outputRevision) then
		self.itemsTab:AddItemTooltip(tooltip, item, nil, true)
	end
end

function ItemDBClass:GetDragValue(index, item)
	return "Item", item
end

function ItemDBClass:OnSelClick(index, item, doubleClick)
	if IsKeyDown("CTRL") then
		-- Add item
		local newItem = new("Item", item.raw)
		newItem:NormaliseQuality()
		self.itemsTab:AddItem(newItem, true)

		-- Equip item if able
		local slotName = newItem:GetPrimarySlot()
		if slotName and self.itemsTab.slots[slotName] then
			if self.itemsTab.slots[slotName].weaponSet == 1 and self.itemsTab.activeItemSet.useSecondWeaponSet then
				-- Redirect to second weapon set
				slotName = slotName .. " Swap"
			end
			if IsKeyDown("SHIFT") then
				-- Redirect to second slot if possible
				local altSlot = slotName:gsub("1","2")
				if self.itemsTab:IsItemValidForSlot(newItem, altSlot) then
					slotName = altSlot
				end
			end
			self.itemsTab.slots[slotName]:SetSelItemId(newItem.id)
		end

		self.itemsTab:PopulateSlots()
		self.itemsTab:AddUndoState()
		self.itemsTab.build.buildFlag = true
	elseif doubleClick then
		self.itemsTab:CreateDisplayItemFromRaw(item.raw, true)
	end
end

function ItemDBClass:OnSelCopy(index, item)
	Copy(item.raw:gsub("\n","\r\n"))
end

function ItemDBClass:OnHoverKeyUp(key)
	if itemLib.wiki.matchesKey(key) then
		local item = self.ListControl:GetHoverValue()
		if item then
			itemLib.wiki.openItem(item)
		end
	end
end
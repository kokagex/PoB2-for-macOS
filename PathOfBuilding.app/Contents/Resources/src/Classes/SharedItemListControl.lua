-- Path of Building
--
-- Class: Item list
-- Shared item list control.
--
local pairs = pairs
local t_insert = table.insert
local t_remove = table.remove

local SharedItemListClass = newClass("SharedItemListControl", "ListControl", function(self, anchor, rect, itemsTab, forceTooltip)
	self.ListControl(anchor, rect, 16, "VERTICAL", true, main.sharedItemList, forceTooltip)
	self.itemsTab = itemsTab
	self.label = "^7"..i18n.t("items.sharedItems.title")
	self.defaultText = "^x7F7F7F"..i18n.t("items.sharedItems.helpText")
	self.dragTargetList = { }
	self.controls.delete = new("ButtonControl", {"BOTTOMRIGHT",self,"TOPRIGHT"}, {0, -2, 60, 18}, i18n.t("items.buttons.delete"), function()
		self:OnSelDelete(self.selIndex, self.selValue)
	end)
	self.controls.delete.enabled = function()
		return self.selValue ~= nil
	end
end)

function SharedItemListClass:GetRowValue(column, index, item)
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

function SharedItemListClass:AddValueTooltip(tooltip, index, item)
	if main.popups[1] then
		tooltip:Clear()
		return
	end
	if tooltip:CheckForUpdate(item, IsKeyDown("SHIFT"), launch.devModeAlt, self.itemsTab.build.outputRevision) then
		self.itemsTab:AddItemTooltip(tooltip, item)
	end
end

function SharedItemListClass:GetDragValue(index, item)
	return "Item", item
end

function SharedItemListClass:ReceiveDrag(type, value, source)
	if type == "Item" then
		local rawItem = { raw = value:BuildRaw() }
		local newItem = new("Item", rawItem.raw)
		if not value.id then
			newItem:NormaliseQuality()
		end
		t_insert(self.list, self.selDragIndex or #self.list, newItem)
	end
end

function SharedItemListClass:OnSelClick(index, item, doubleClick)
	if doubleClick then
		self.itemsTab:CreateDisplayItemFromRaw(item.raw, true)
		self.selDragging = false
	end
end

function SharedItemListClass:OnSelCopy(index, item)
	Copy(item:BuildRaw():gsub("\n","\r\n"))
end

function SharedItemListClass:OnSelDelete(index, item)
	main:OpenConfirmPopup(i18n.t("items.popups.deleteItemTitle"), "Are you sure you want to remove '"..item.name.."' from the shared item list?", i18n.t("items.buttons.delete"), function()
		t_remove(self.list, index)
		self.selIndex = nil
		self.selValue = nil
	end)
end

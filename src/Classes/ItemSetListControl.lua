-- Path of Building
--
-- Class: Item Set List
-- Item set list control.
--
local t_insert = table.insert

local ItemSetListClass = newClass("ItemSetListControl", "ListControl", function(self, anchor, rect, itemsTab)
	self.ListControl(anchor, rect, 16, "VERTICAL", true, itemsTab.itemSetOrderList)
	self.itemsTab = itemsTab
	self.itemSetService = new("ItemSetService", itemsTab)
	self.controls.copy = new("ButtonControl", {"BOTTOMLEFT",self,"TOP"}, {2, -4, 60, 18}, i18n.t("items.buttons.copy"), function()
		self:CopyItemSet(self.selValue)
	end)
	self.controls.copy.enabled = function()
		return self.selValue ~= nil
	end
	self.controls.delete = new("ButtonControl", {"LEFT",self.controls.copy,"RIGHT"}, {4, 0, 60, 18}, i18n.t("items.buttons.delete"), function()
		self:OnSelDelete(self.selIndex, self.selValue)
	end)
	self.controls.delete.enabled = function()
		return self.selValue ~= nil and #self.list > 1
	end
	self.controls.rename = new("ButtonControl", {"BOTTOMRIGHT",self,"TOP"}, {-2, -4, 60, 18}, i18n.t("items.buttons.rename"), function()
		self:RenameItemSet(self.selValue)
	end)
	self.controls.rename.enabled = function()
		return self.selValue ~= nil
	end
	self.controls.new = new("ButtonControl", {"RIGHT",self.controls.rename,"LEFT"}, {-4, 0, 60, 18}, i18n.t("items.buttons.new"), function()
		self:CreateItemSet()
	end)
end)

function ItemSetListClass:CreateItemSet()
	local controls = {}
	controls.label = new("LabelControl", nil, { 0, 20, 0, 16 }, i18n.t("items.popups.enterNewSetName"))
	controls.edit = new("EditControl", nil, { 0, 40, 350, 20 }, i18n.t("items.popups.newItemSetDefault"), nil, nil, 100, function(buf)
		controls.save.enabled = buf:match("%S")
	end)
	controls.save = new("ButtonControl", nil, { -45, 70, 80, 20 }, i18n.t("items.buttons.save"), function()
		self.itemSetService:NewItemSet(controls.edit.buf)
		main:ClosePopup()
	end)
	controls.save.enabled = false
	controls.cancel = new("ButtonControl", nil, { 45, 70, 80, 20 }, i18n.t("items.buttons.cancel"), function()
		main:ClosePopup()
	end)
	main:OpenPopup(370, 100, i18n.t("items.popups.createItemSetTitle"), controls, "save", "edit", "cancel")
end

function ItemSetListClass:CopyItemSet(selValue)
	local itemSet = self.itemsTab.itemSets[selValue]
	local controls = {}
	controls.label = new("LabelControl", nil, { 0, 20, 0, 16 }, i18n.t("items.popups.enterSetName"))
	controls.edit = new("EditControl", nil, { 0, 40, 350, 20 }, itemSet.title or i18n.t("items.status.default"), nil, nil, 100, function(buf)
		controls.save.enabled = buf:match("%S")
	end)
	controls.save = new("ButtonControl", nil, { -45, 70, 80, 20 }, i18n.t("items.buttons.save"), function()
		self.itemSetService:CopyItemSet(selValue, controls.edit.buf)
		main:ClosePopup()
	end)
	controls.save.enabled = false
	controls.cancel = new("ButtonControl", nil, { 45, 70, 80, 20 }, i18n.t("items.buttons.cancel"), function()
		main:ClosePopup()
	end)
	main:OpenPopup(370, 100, i18n.t("items.popups.copyItemSetTitle"), controls, "save", "edit", "cancel")
end

function ItemSetListClass:RenameItemSet(selValue)
	local itemSet = self.itemsTab.itemSets[selValue]
	local controls = {}
	local setName = itemSet.title or i18n.t("items.status.default")
	controls.label = new("LabelControl", nil, { 0, 20, 0, 16 }, i18n.t("items.popups.enterSetName"))
	controls.edit = new("EditControl", nil, { 0, 40, 350, 20 }, setName, nil, nil, 100, function(buf)
		controls.save.enabled = buf:match("%S")
	end)
	controls.save = new("ButtonControl", nil, { -45, 70, 80, 20 }, i18n.t("items.buttons.save"), function()
		self.itemSetService:RenameItemSet(selValue, controls.edit.buf)
		main:ClosePopup()
	end)
	controls.save.enabled = false
	controls.cancel = new("ButtonControl", nil, { 45, 70, 80, 20 }, i18n.t("items.buttons.cancel"), function()
		main:ClosePopup()
	end)
	main:OpenPopup(370, 100, setName and i18n.t("items.popups.renameTitle") or i18n.t("items.popups.setNameTitle"), controls, "save", "edit", "cancel")
end

function ItemSetListClass:GetRowValue(column, index, itemSetId)
	local itemSet = self.itemsTab.itemSets[itemSetId]
	if column == 1 then
		return (itemSet.title or i18n.t("items.status.default")) .. (itemSetId == self.itemsTab.activeItemSetId and "  ^9(" .. i18n.t("items.status.current") .. ")" or "")
	end
end

function ItemSetListClass:AddValueTooltip(tooltip, index, itemSetId)
	local itemSet = self.itemsTab.itemSets[itemSetId]
	tooltip:Clear()
	self.itemsTab:AddItemSetTooltip(tooltip, itemSet)
end

function ItemSetListClass:GetDragValue(index, itemSetId)
	return "ItemList", self.itemsTab.itemSets[itemSetId]
end

function ItemSetListClass:CanReceiveDrag(type, value)
	return type == "SharedItemList"
end

function ItemSetListClass:ReceiveDrag(type, value, source)
	if type == "SharedItemList" then
		local itemSet = self.itemsTab:CreateItemSet()
		itemSet.title = value.title
		for slotName, item in pairs(value.slots) do
			local newItem = new("Item", item.raw)
			newItem:NormaliseQuality()
			self.itemsTab:AddItem(newItem, true)
			itemSet[slotName].selItemId = newItem.id
		end
		t_insert(self.list, self.selDragIndex or #self.list + 1, itemSet.id)
		self.itemsTab:AddUndoState()
	end
end

function ItemSetListClass:OnOrderChange()
	self.itemsTab.modFlag = true
end

function ItemSetListClass:OnSelClick(index, itemSetId, doubleClick)
	if doubleClick and itemSetId ~= self.itemsTab.activeItemSetId then
		self.itemsTab:SetActiveItemSet(itemSetId)
		self.itemsTab:AddUndoState()
	end
end

function ItemSetListClass:OnSelDelete(index, itemSetId)
	local itemSet = self.itemsTab.itemSets[itemSetId]
	if #self.list > 1 then
		main:OpenConfirmPopup(i18n.t("items.popups.deleteItemSetTitle"),
			i18n.t("items.popups.deleteItemSetMsg", {name = itemSet.title or i18n.t("items.status.default")}), i18n.t("items.buttons.delete"), function()
				self.itemSetService:DeleteItemSet(itemSetId, index)
				self.selIndex = nil
				self.selValue = nil
			end)
	end
end

function ItemSetListClass:OnSelKeyDown(index, itemSetId, key)
	if key == "F2" then
		self:RenameItemSet(itemSetId)
	end
end

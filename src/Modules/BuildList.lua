-- Path of Building
--
-- Module: Build List
-- Displays the list of builds.
--
local pairs = pairs
local ipairs = ipairs
local t_insert = table.insert

local buildListHelpers = LoadModule("Modules/BuildListHelpers")
local buildSortDropList = buildListHelpers.buildSortDropList
-- Apply i18n translations to shared sort dropdown labels
buildSortDropList[1].label = i18n.t("buildList.sortByName")
buildSortDropList[2].label = i18n.t("buildList.sortByClass")
buildSortDropList[3].label = i18n.t("buildList.sortByLastEdited")
buildSortDropList[4].label = i18n.t("buildList.sortByLevel")

local listMode = new("ControlHost")

function listMode:Init(selBuildName, subPath)
	if self.initialised then
		self.subPath = subPath or self.subPath
		self.controls.buildList.controls.path:SetSubPath(self.subPath)
		self.controls.buildList:SelByFileName(selBuildName and selBuildName..".xml")
		--if main.showPublicBuilds then
		if false then
			self.controls.ExtBuildList = self:getPublicBuilds()
		else
			self.controls.ExtBuildList = nil
		end
		self:BuildList()
		self:SelectControl(self.controls.buildList)
		return
	end

	local s = main.screenScale or 1

	self.anchor = new("Control", nil, {0, 4 * s, 0, 0})
	self.anchor.x = function()
		return main.screenW / 2
	end

	self.subPath = subPath or ""
	self.list = { }

	self.controls.new = new("ButtonControl", {"TOP",self.anchor,"TOP"}, {-259 * s, 0, 60 * s, 20 * s}, i18n.t("buildList.newBuild"), function()
		main:SetMode("BUILD", false, "Unnamed build")
	end)
	self.controls.newFolder = new("ButtonControl", {"LEFT",self.controls.new,"RIGHT"}, {8 * s, 0, 90 * s, 20 * s}, i18n.t("buildList.newFolder"), function()
		self.controls.buildList:NewFolder()
	end)
	self.controls.open = new("ButtonControl", {"LEFT",self.controls.newFolder,"RIGHT"}, {8 * s, 0, 60 * s, 20 * s}, i18n.t("buildList.openBuild"), function()
		self.controls.buildList:LoadBuild(self.controls.buildList.selValue)
	end)
	self.controls.open.enabled = function() return self.controls.buildList.selValue ~= nil end
	self.controls.copy = new("ButtonControl", {"LEFT",self.controls.open,"RIGHT"}, {8 * s, 0, 60 * s, 20 * s}, i18n.t("buildList.copyBuild"), function()
		self.controls.buildList:RenameBuild(self.controls.buildList.selValue, true)
	end)
	self.controls.copy.enabled = function() return self.controls.buildList.selValue ~= nil end
	self.controls.rename = new("ButtonControl", {"LEFT",self.controls.copy,"RIGHT"}, {8 * s, 0, 60 * s, 20 * s}, i18n.t("buildList.renameBuild"), function()
		self.controls.buildList:RenameBuild(self.controls.buildList.selValue)
	end)
	self.controls.rename.enabled = function() return self.controls.buildList.selValue ~= nil end
	self.controls.delete = new("ButtonControl", {"LEFT",self.controls.rename,"RIGHT"}, {8 * s, 0, 60 * s, 20 * s}, i18n.t("buildList.deleteBuild"), function()
		self.controls.buildList:DeleteBuild(self.controls.buildList.selValue)
	end)
	self.controls.delete.enabled = function() return self.controls.buildList.selValue ~= nil end
	self.controls.sort = new("DropDownControl", {"LEFT",self.controls.delete,"RIGHT"}, {8 * s, 0, 140 * s, 20 * s}, buildSortDropList, function(index, value)
		main.buildSortMode = value.sortMode
		self:SortList()
	end)
	self.controls.sort:SelByValue(main.buildSortMode, "sortMode")
	self.controls.buildList = new("BuildListControl", {"TOP",self.anchor,"TOP"}, {0, 75 * s, 900 * s, 0}, self)
	self.controls.buildList.height = function()
		return main.screenH - 80 * s
	end
	local buildListWidth = function ()
		--if main.showPublicBuilds then
		if false then
			return math.min((main.screenW / 2), 900 * s)
		else
			return 900 * s
		end
	end
	local buildListOffset = function ()
		--if main.showPublicBuilds then
		if false then
			local offset = math.min(450 * s, main.screenW / 4)
			return offset - 450 * s
		else
			return 0
		end
	end

	self.controls.buildList.width = buildListWidth
	self.controls.buildList.x = buildListOffset

	--if main.showPublicBuilds then
	if false then
		self.controls.ExtBuildList = self:getPublicBuilds()
	end

	self.controls.searchText = new("EditControl", {"TOP",self.anchor,"TOP"}, {0, 25 * s, 640 * s, 20 * s}, self.filterBuildList, "Search", "%c%(%)", 100, function(buf)
		main.filterBuildList = buf
		self:BuildList()
	end, nil, nil, true)
	self.controls.searchText.width = buildListWidth
	self.controls.searchText.x = buildListOffset

	self:BuildList()
	self.controls.buildList:SelByFileName(selBuildName and selBuildName..".xml")
	self:SelectControl(self.controls.buildList)

	self.initialised = true
end

function listMode:getPublicBuilds()
	local buildProviders = {
		{
			name = "PoB Archives",
			impl = new("PoBArchivesProvider", "builds")
		}
	}
	local extBuildList = new("ExtBuildListControl", {"LEFT",self.controls.buildList,"RIGHT"}, {25, 0, main.screenW * 1 / 4 - 50, 0}, buildProviders)
	extBuildList:Init("PoB Archives")
	extBuildList.height = function()
		return main.screenH - 80
	end
	extBuildList.width = function ()
		return math.max((main.screenW / 4 - 50), 400)
	end
	return extBuildList
end
function listMode:Shutdown()
end

function listMode:GetArgs()
	return self.controls.buildList.selValue and self.controls.buildList.selValue.buildName or false, self.subPath
end

function listMode:OnFrame(inputEvents)
	local textInputActive = main.textInputActive or (self.selControl and self.selControl.OnChar and self.selControl.hasFocus)
	for id, event in ipairs(inputEvents) do
		if event.type == "KeyDown" then
			if event.key == "v" and IsKeyDown("CTRL") and not textInputActive then
				if self.controls.buildList.copyBuild then
					local build = self.controls.buildList.copyBuild
					if build.subPath ~= self.subPath then
						if build.folderName then
							main:CopyFolder(build.folderName, main.buildPath..build.subPath, main.buildPath..self.subPath)
						else
							copyFile(build.fullFileName, self:GetDestName(self.subPath, build.fileName))
						end
						self:BuildList()
					else
						self.controls.buildList:RenameBuild(build, true)
					end
					self.controls.buildList.copyBuild = nil
				elseif self.controls.buildList.cutBuild then
					local build = self.controls.buildList.cutBuild
					if build.subPath ~= self.subPath then
						if build.folderName then
							main:MoveFolder(build.folderName, main.buildPath..build.subPath, main.buildPath..self.subPath)
						else
							os.rename(build.fullFileName, self:GetDestName(self.subPath, build.fileName))
						end
						self:BuildList()
					end
					self.controls.buildList.cutBuild = nil
				end
			elseif event.key == "n" and IsKeyDown("CTRL") and not textInputActive then
				main:SetMode("BUILD", false, "Unnamed build")
			elseif event.key == "MOUSE4" then
				self.controls.buildList.controls.path:Undo()
			elseif event.key == "MOUSE5" then
				self.controls.buildList.controls.path:Redo()
			end
		end
	end
	self:ProcessControlsInput(inputEvents, main.viewPort)

	main:DrawBackground(main.viewPort)

	self:DrawControls(main.viewPort)
end

function listMode:GetDestName(subPath, fileName)
	local i = 2
	local destName = fileName
	while true do
		local test = io.open(destName, "r")
		if test then
			destName = fileName .. "[" .. i .. "]"
			i = i + 1
		else
			break
		end
	end
	return main.buildPath..subPath..destName
end

function listMode:BuildList()
	wipeTable(self.list)
	local scanned = buildListHelpers.ScanFolder(self.subPath, main.filterBuildList or "")
	for _, entry in ipairs(scanned) do
		t_insert(self.list, entry)
	end
	self:SortList()
end

function listMode:SortList()
	local oldSelFileName = self.controls.buildList.selValue and self.controls.buildList.selValue.fileName
	buildListHelpers.SortList(self.list, main.buildSortMode)
	if oldSelFileName then
		self.controls.buildList:SelByFileName(oldSelFileName)
	end
end

return listMode

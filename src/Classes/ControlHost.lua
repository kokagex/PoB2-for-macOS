-- Path of Building
--
-- Class: Control Host
-- Host for UI controls
--

local ControlHostClass = newClass("ControlHost", function(self)
	self.controls = { }
end)

function ControlHostClass:SelectControl(newSelControl)
	if self.selControl == newSelControl then
		return
	end
	if self.selControl then
		if self.selControl.selDragActive and self.selControl.dragTargetList then
			return
		end
		self.selControl:SetFocus(false)
	end
	self.selControl = newSelControl
	if self.selControl then
		self.selControl:SetFocus(true)
	end
end

function ControlHostClass:GetMouseOverControl()
	for _, control in pairs(self.controls) do
		if control.IsMouseOver and control:IsMouseOver() then
			return control
		end
	end
end

function ControlHostClass:ProcessControlsInput(inputEvents, viewPort)
	local function handleEvent(id, event)
		if event.consumed then return end
		if event.type == "KeyDown" then
			if not self.selControl and not event.key:match("BUTTON") then
				local mOverControl = self:GetMouseOverControl()
				if mOverControl and mOverControl.OnChar then
					self:SelectControl(mOverControl)
					if mOverControl.OnKeyDown then
						self:SelectControl(mOverControl:OnKeyDown(event.key, event.doubleClick))
					end
					event.consumed = true
					return
				end
			end
			if self.selControl then
				self:SelectControl(self.selControl:OnKeyDown(event.key, event.doubleClick))
				event.consumed = true
				if not self.selControl and event.key:match("BUTTON") then
					self:SelectControl()
					if isMouseInRegion(viewPort) then
						local mOverControl = self:GetMouseOverControl()
						if mOverControl and mOverControl.OnKeyDown then
							self:SelectControl(mOverControl:OnKeyDown(event.key, event.doubleClick))
						end
					end
				end
			end
			if not self.selControl and event.key:match("BUTTON") then
				self:SelectControl()
				if isMouseInRegion(viewPort) then
					local mOverControl = self:GetMouseOverControl()
					if mOverControl and mOverControl.OnKeyDown then
						self:SelectControl(mOverControl:OnKeyDown(event.key, event.doubleClick))
						event.consumed = true
					end
				end
			end
		elseif event.type == "KeyUp" then
			local selControl = self.selControl

			if selControl then
				if selControl.OnKeyUp then
					self:SelectControl(selControl:OnKeyUp(event.key))
				end
				
				event.consumed = true
			end

			local mOverControl = self:GetMouseOverControl(viewPort)

			-- Avoid calculating isMouseInRegion as much as possible as it's expensive
			if mOverControl and (not selControl or mOverControl.OnHoverKeyUp) then
				if isMouseInRegion(viewPort) then
					if not selControl and mOverControl.OnKeyUp and mOverControl:OnKeyUp(event.key) then
						event.consumed = true
					end
	
					if mOverControl.OnHoverKeyUp then
						mOverControl:OnHoverKeyUp(event.key)
					end
				end
			end
		elseif event.type == "Char" then
			if not self.selControl then
				local mOverControl = self:GetMouseOverControl()
				if mOverControl and mOverControl.OnChar then
					self:SelectControl(mOverControl)
				end
			end
			if self.selControl then
				if self.selControl.OnChar then
					self:SelectControl(self.selControl:OnChar(event.key))
				end
				event.consumed = true
			end
		end
	end

	-- Process mouse button downs first so focus is set before key events in the same frame.
	for id, event in ipairs(inputEvents) do
		if event and event.type == "KeyDown" and event.key:match("BUTTON") then
			handleEvent(id, event)
		end
	end
	for id, event in ipairs(inputEvents) do
		if event and not (event.type == "KeyDown" and event.key:match("BUTTON")) then
			handleEvent(id, event)
		end
	end
end

function ControlHostClass:DrawControls(viewPort, selControl)
	local noTooltipArg
	-- Pass 1a: Draw section backgrounds first.
	-- SetDrawLayer is a no-op in the Metal backend, so section fills can hide controls
	-- if drawn later in an arbitrary table iteration order.
	for _, control in pairs(self.controls) do
		if control:IsShown() and control.Draw and not control.dropped and control._className == "SectionControl" then
			noTooltipArg = (self.selControl and self.selControl.hasFocus and self.selControl ~= control) or (selControl and selControl.hasFocus and selControl ~= control)
			control:Draw(viewPort, noTooltipArg)
		end
	end
	-- Pass 1b: Draw all other non-dropped controls
	for _, control in pairs(self.controls) do
		if control:IsShown() and control.Draw and not control.dropped and control._className ~= "SectionControl" then
			noTooltipArg = (self.selControl and self.selControl.hasFocus and self.selControl ~= control) or (selControl and selControl.hasFocus and selControl ~= control)
			control:Draw(viewPort, noTooltipArg)
		end
	end
	-- Pass 2: Draw dropped controls last (on top of everything)
	-- This fixes z-order for open dropdown lists since SetDrawLayer is a no-op in Metal backend
	for _, control in pairs(self.controls) do
		if control:IsShown() and control.Draw and control.dropped then
			noTooltipArg = (self.selControl and self.selControl.hasFocus and self.selControl ~= control) or (selControl and selControl.hasFocus and selControl ~= control)
			control:Draw(viewPort, noTooltipArg)
		end
	end
end

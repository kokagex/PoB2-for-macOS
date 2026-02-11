-- Path of Building
--
-- Class: Label Control
-- Simple text label.
--
local LabelClass = newClass("LabelControl", "Control", function(self, anchor, rect, label)
	self.Control(anchor, rect)
	self.label = label
	self.width = function()
		local labelText = self:GetProperty("label")
		local h = self:GetProperty("height")
		-- Calculate max width across all lines for multiline labels
		local maxW = 0
		for line in (labelText .. "\n"):gmatch("([^\n]*)\n") do
			local w = DrawStringWidth(h, "VAR", line)
			if w > maxW then
				maxW = w
			end
		end
		return maxW
	end
end)

function LabelClass:Draw()
	local x, y = self:GetPos()
	local h = self:GetProperty("height")
	local labelText = self:GetProperty("label")
	-- Split by newlines and draw each line separately
	-- (DrawString in Metal backend does not handle \n)
	local lineY = y
	for line in (labelText .. "\n"):gmatch("([^\n]*)\n") do
		DrawString(x, lineY, "LEFT", h, "VAR", line)
		lineY = lineY + h
	end
end
local _, HUI = ...

local M = { name = "errors" }
table.insert(HUI.modules, M)

local function apply()
	-- Hide the red "UI error" text like:
	-- "You have no target", "Spell is not ready yet", etc.
	if not UIErrorsFrame then return end

	-- Disable the event stream that feeds UIErrorsFrame.
	if UIErrorsFrame.UnregisterEvent then
		UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
		UIErrorsFrame:UnregisterEvent("UI_INFO_MESSAGE")
	end

	-- Some clients still call the handler directly; neutralize it.
	if UIErrorsFrame.SetScript then
		UIErrorsFrame:SetScript("OnEvent", nil)
	end

	-- And keep it hidden if something tries to show it.
	if UIErrorsFrame.Hide then
		UIErrorsFrame:Hide()
	end
	if UIErrorsFrame.SetScript then
		UIErrorsFrame:SetScript("OnShow", function(self) self:Hide() end)
	end
end

function M:Apply()
	apply()
end


local _, HUI = ...

local M = { name = "combopoints" }
table.insert(HUI.modules, M)

local function forceHide(f)
	if not f then return end
	if f.UnregisterAllEvents then f:UnregisterAllEvents() end
	if f.Hide then f:Hide() end
	if f.SetScript then
		f:SetScript("OnShow", function(self) self:Hide() end)
	end
end

local function apply()
	-- Classic target-frame combo points have varied names over time; try common frames.
	forceHide(_G.ComboFrame)
	forceHide(_G.ComboPointPlayerFrame)
	forceHide(_G.TargetFrameComboPoints)
	forceHide(_G.ComboPointFrame)

	-- Some versions store combo points as regions on TargetFrame.
	if _G.TargetFrame and _G.TargetFrame.comboPoints then
		forceHide(_G.TargetFrame.comboPoints)
	end
end

function M:Apply()
	if not M._ev then
		local ev = CreateFrame("Frame")
		M._ev = ev
		ev:RegisterEvent("PLAYER_ENTERING_WORLD")
		ev:RegisterEvent("PLAYER_TARGET_CHANGED")
		ev:SetScript("OnEvent", function() apply() end)
	end
	apply()
end


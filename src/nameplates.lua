local _, HUI = ...

local M = { name = "nameplates" }
table.insert(HUI.modules, M)

local function forceHide(f)
	if not f then return end
	if f.UnregisterAllEvents then f:UnregisterAllEvents() end
	if f.Hide then f:Hide() end
	if f.SetScript then
		f:SetScript("OnShow", function(self) self:Hide() end)
	end
end

local function hideNameplateComboPoints()
	-- Try the common layouts across Classic/Retail variants.
	local n = _G.NamePlateDriverFrame
	if not n then return end

	-- Retail-ish
	local bar = n.classNameplateBar
	if bar then
		forceHide(bar.ComboPointFrame)
		forceHide(bar.comboPointFrame)
	end

	-- Some clients expose a single global class bar frame.
	forceHide(_G.ClassNameplateBarFrame and _G.ClassNameplateBarFrame.ComboPointFrame)
	forceHide(_G.ClassNameplateBarFrame and _G.ClassNameplateBarFrame.comboPointFrame)
end

local function apply()
	hideNameplateComboPoints()

	-- Blizzard recreates/shows these frequently; keep hiding after updates.
	if not M._hooked and hooksecurefunc then
		M._hooked = true
		if _G.NamePlateDriverFrame_UpdateClassNameplateBars then
			hooksecurefunc("NamePlateDriverFrame_UpdateClassNameplateBars", hideNameplateComboPoints)
		end
		if _G.NamePlateDriverFrame then
			hooksecurefunc(_G.NamePlateDriverFrame, "UpdateNamePlateOptions", hideNameplateComboPoints)
		end
	end
end

function M:Apply()
	if not M._ev then
		local ev = CreateFrame("Frame")
		M._ev = ev
		ev:RegisterEvent("PLAYER_ENTERING_WORLD")
		ev:SetScript("OnEvent", function() apply() end)
	end
	apply()
end


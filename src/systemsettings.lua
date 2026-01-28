local _, HUI = ...

local M = { name = "systemsettings" }
table.insert(HUI.modules, M)

local function setCVar(name, value)
	if type(SetCVar) ~= "function" then return end
	pcall(SetCVar, name, value)
end

local function applySettings()
	-- Schnell plündern (Auto Loot)
	setCVar("autoLootDefault", "1")

	-- Show all action bars
	-- (some clients also track main bar visibility separately)
	setCVar("showMainActionBar", "1")
	setCVar("showActionBar1", "1")
	setCVar("bottomLeftActionBar", "1")
	setCVar("bottomRightActionBar", "1")
	setCVar("rightActionBar", "1")
	setCVar("rightTwoActionBar", "1")

	-- Always show action bars (show empty buttons / bar art)
	setCVar("alwaysShowActionBars", "1")

	-- Force UI to re-read action bar CVars.
	pcall(function()
		if type(_G.InterfaceOptions_UpdateActionBars) == "function" then _G.InterfaceOptions_UpdateActionBars() end
		if type(_G.InterfaceOptions_UpdateMultiActionBars) == "function" then _G.InterfaceOptions_UpdateMultiActionBars() end
		if type(_G.MultiActionBar_Update) == "function" then _G.MultiActionBar_Update() end
		if type(_G.ActionBarController_UpdateAll) == "function" then _G.ActionBarController_UpdateAll() end
	end)
end

function M:Apply()
	applySettings()

	if M._ev then return end
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:SetScript("OnEvent", applySettings)
	M._ev = f
end

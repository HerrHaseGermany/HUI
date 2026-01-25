local _, HUI = ...

local M = { name = "tooltip" }
table.insert(HUI.modules, M)

-- Hardcoded tooltip position (spells + units)
local POINT, RELPOINT = "BOTTOMRIGHT", "BOTTOMRIGHT"
local X, Y = -15, 150

local function apply()
	if not GameTooltip or not GameTooltip.SetOwner or not hooksecurefunc then return end
	if M._hooked then return end
	M._hooked = true

	hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
		if not tooltip then return end
		tooltip:SetOwner(parent or UIParent, "ANCHOR_NONE")
		tooltip:ClearAllPoints()
		tooltip:SetPoint(POINT, UIParent, RELPOINT, X, Y)
	end)
end

function M:Apply()
	apply()
end


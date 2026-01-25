local ADDON_NAME, HUI = ...

HUI.util = HUI.util or {}
local U = HUI.util

local _G = _G

function U.Tex(parent, layer)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetTexture("Interface\\Buttons\\WHITE8x8")
	return t
end

function U.Font(parent, size, outline)
	local f = parent:CreateFontString(nil, "OVERLAY")
	f:SetFont(STANDARD_TEXT_FONT, size or 12, outline and "OUTLINE" or nil)
	f:SetJustifyH("LEFT")
	f:SetJustifyV("MIDDLE")
	f:SetTextColor(1, 1, 1)
	return f
end

function U.SafeHide(frame)
	if frame and frame.Hide then frame:Hide() end
end

function U.UnregisterAndHide(frame)
	if not frame then return end
	if frame.UnregisterAllEvents then frame:UnregisterAllEvents() end
	if frame.SetParent then frame:SetParent(HiddenFrame or _G.UIParent) end
	U.SafeHide(frame)
end

function U.ForEachNamed(prefix, from, to, fn)
	for i = from, to do
		local obj = _G[prefix .. i]
		if obj then fn(obj, i) end
	end
end

function U.Clamp(v, minV, maxV)
	if v < minV then return minV end
	if v > maxV then return maxV end
	return v
end

function U.CreateMover(name, label)
	local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	f:SetBackdropBorderColor(1, 0.82, 0, 1)
	f:SetBackdropColor(0, 0, 0, 0.35)

	local t = U.Font(f, 12, true)
	t:SetPoint("CENTER", f, "CENTER", 0, 0)
	t:SetText(label or name)

	f._huiLabel = t

	f:SetScript("OnDragStart", function(self)
		if InCombatLockdown and InCombatLockdown() then return end
		self:StartMoving()
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		if self._huiOnMoved then self:_huiOnMoved() end
	end)

	return f
end

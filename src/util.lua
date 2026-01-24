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

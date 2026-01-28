local _, HUI = ...

local M = { name = "camera" }
table.insert(HUI.modules, M)

local MAX_ZOOM = 4.0

local function setMaxZoom()
	if type(SetCVar) ~= "function" then return end
	-- Classic-era max camera zoom factor.
	pcall(SetCVar, "cameraDistanceMaxZoomFactor", MAX_ZOOM)
end

function M:Apply()
	setMaxZoom()
	if M._ev then return end
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:SetScript("OnEvent", setMaxZoom)
	M._ev = f
end


local _, HUI = ...

local M = { name = "flighttimer" }
table.insert(HUI.modules, M)

local BAR_W, BAR_H = 500, 30
local COLOR_BG = { 0, 0, 0, 0.55 }
local COLOR_BORDER = { 0, 0, 0, 1 }
local COLOR_FILL = { 0.15, 0.55, 0.95, 1 } -- bright blue

local function formatMMSS(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%02d:%02d", m, s)
end

local function ensure()
	if M._f then return end

	local f = CreateFrame("Frame", "HUI_FlightTimer", UIParent, "BackdropTemplate")
	f:SetSize(BAR_W, BAR_H)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	f:SetFrameStrata("HIGH")
	f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	f:SetBackdropColor(unpack(COLOR_BG))
	f:SetBackdropBorderColor(unpack(COLOR_BORDER))
	f:Hide()

	local bar = CreateFrame("StatusBar", nil, f)
	bar:SetAllPoints(f)
	bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	bar:SetStatusBarColor(unpack(COLOR_FILL))
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(1)
	f._bar = bar

	local timeText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	timeText:SetPoint("CENTER", bar, "CENTER", 0, 0)
	timeText:SetText("00:00")
	f._timeText = timeText

	local destText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	destText:SetPoint("RIGHT", bar, "RIGHT", -10, 0)
	destText:SetJustifyH("RIGHT")
	destText:SetText("")
	f._destText = destText

	f._elapsed = 0
	f._tick = 0
	f:SetScript("OnUpdate", function(self, dt)
		self._tick = (self._tick or 0) + (dt or 0)
		if self._tick < 0.10 then return end
		self._tick = 0
		self._elapsed = (GetTime() or 0) - (self._startTime or 0)
		self._timeText:SetText(formatMMSS(self._elapsed))
	end)

	M._f = f
end

local function show()
	ensure()
	local f = M._f
	f._startTime = GetTime() or 0
	f._timeText:SetText("00:00")
	f._destText:SetText(M._destName or "")
	f:Show()
end

local function hide()
	if not M._f then return end
	M._f:Hide()
	M._destName = nil
end

local function refresh()
	if UnitOnTaxi and UnitOnTaxi("player") then
		if not (M._f and M._f:IsShown()) then
			show()
		end
	else
		hide()
	end
end

function M:Apply()
	ensure()
	if M._hooked then
		refresh()
		return
	end
	M._hooked = true

	if hooksecurefunc then
		hooksecurefunc("TakeTaxiNode", function(slot)
			if not slot then return end
			local name = TaxiNodeName and TaxiNodeName(slot) or nil
			M._destName = name or "In Flight"
		end)
	end

	local ef = CreateFrame("Frame")
	ef:RegisterEvent("PLAYER_CONTROL_LOST")
	ef:RegisterEvent("PLAYER_CONTROL_GAINED")
	ef:RegisterEvent("PLAYER_ENTERING_WORLD")
	ef:SetScript("OnEvent", function()
		refresh()
	end)

	refresh()
end

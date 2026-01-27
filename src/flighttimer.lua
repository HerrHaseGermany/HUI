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

local function routeKey(fromName, toName)
	return (fromName or "?") .. "->" .. (toName or "?")
end

local function getRouteDB()
	local db = (HUI and HUI.GetDB and HUI:GetDB()) or nil
	if not db then return nil end
	db.flightTimes = db.flightTimes or {}
	return db.flightTimes
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
	f._bgShown = true

	local bar = CreateFrame("StatusBar", nil, f)
	bar:SetAllPoints(f)
	bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	bar:SetStatusBarColor(unpack(COLOR_FILL))
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(1)
	f._bar = bar
	bar:Hide()

	-- Text lives on the frame so it can show even when the blue bar is hidden.
	local timeText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	timeText:SetPoint("CENTER", f, "CENTER", 0, 0)
	timeText:SetText("00:00")
	f._timeText = timeText

	local destText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	destText:SetPoint("RIGHT", f, "RIGHT", -10, 0)
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
		local remain
		if self._duration and self._duration > 0 then
			if self._bar and self._bar.Show then self._bar:Show() end
			if not self._bgShown then
				self:SetBackdropColor(unpack(COLOR_BG))
				self:SetBackdropBorderColor(unpack(COLOR_BORDER))
				self._bgShown = true
			end
			remain = math.max(0, (self._duration or 0) - self._elapsed)
			self._timeText:SetText(formatMMSS(remain))
		else
			if self._bar and self._bar.Hide then self._bar:Hide() end
			-- "Unknown route": show just text, no box.
			if self._bgShown then
				self:SetBackdropColor(0, 0, 0, 0)
				self:SetBackdropBorderColor(0, 0, 0, 0)
				self._bgShown = false
			end
			self._timeText:SetText(formatMMSS(self._elapsed))
		end
	end)

	M._f = f
end

local function show()
	ensure()
	local f = M._f
	f._startTime = GetTime() or 0
	f._timeText:SetText("00:00")
	f._destText:SetText(M._destName or "")
	f._duration = M._destDuration or 0
	-- Initial visual mode.
	if f._duration and f._duration > 0 then
		f._bgShown = true
		f:SetBackdropColor(unpack(COLOR_BG))
		f:SetBackdropBorderColor(unpack(COLOR_BORDER))
		if f._bar and f._bar.Show then f._bar:Show() end
	else
		f._bgShown = false
		f:SetBackdropColor(0, 0, 0, 0)
		f:SetBackdropBorderColor(0, 0, 0, 0)
		if f._bar and f._bar.Hide then f._bar:Hide() end
	end
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
			M._startFrom = (GetMinimapZoneText and GetMinimapZoneText()) or (GetRealZoneText and GetRealZoneText()) or ""

			-- Known duration? show countdown.
			local db = getRouteDB()
			if db then
				local key = routeKey(M._startFrom, M._destName)
				M._destDuration = tonumber(db[key] or 0) or 0
			else
				M._destDuration = 0
			end
		end)
	end

	local ef = CreateFrame("Frame")
	ef:RegisterEvent("PLAYER_CONTROL_LOST")
	ef:RegisterEvent("PLAYER_CONTROL_GAINED")
	ef:RegisterEvent("PLAYER_ENTERING_WORLD")
	ef:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_CONTROL_LOST" then
			-- Taxi started; ensure we show with the current known duration.
			refresh()
			return
		end
		if event == "PLAYER_CONTROL_GAINED" then
			-- Taxi ended; record actual duration for this route.
			if M._f and M._f._startTime and M._startFrom and M._destName then
				local elapsed = (GetTime() or 0) - (M._f._startTime or 0)
				if elapsed and elapsed > 5 then
					local db = getRouteDB()
					if db then
						local key = routeKey(M._startFrom, M._destName)
						-- Smooth updates a bit to avoid wild jitter.
						local prev = tonumber(db[key] or 0) or 0
						if prev <= 0 then
							db[key] = elapsed
						else
							db[key] = (prev * 0.7) + (elapsed * 0.3)
						end
					end
				end
			end
			-- Hide immediately; UnitOnTaxi can lag a bit after regaining control.
			hide()
			return
		end
		refresh()
	end)

	refresh()
end

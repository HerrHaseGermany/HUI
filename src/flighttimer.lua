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

local function cleanTaxiName(name)
	if type(name) ~= "string" then return name end
	return name:match("^[^,]+") or name
end

local function routeKey(fromName, toName)
	return (fromName or "?") .. "->" .. (toName or "?")
end

local function getContinent()
	if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then return nil end
	local mapID = C_Map.GetBestMapForUnit("player")
	if not mapID then return nil end
	local info = C_Map.GetMapInfo(mapID)
	while info and info.mapType and info.mapType > 2 do
		info = C_Map.GetMapInfo(info.parentMapID)
	end
	if info and info.mapType == 2 then
		return info.mapID
	end
	return nil
end

local function formatPos(x, y)
	if not x or not y then return nil end
	return string.format("%0.2f", x) .. ":" .. string.format("%0.2f", y)
end

local function getNumTaxiNodes()
	if NumTaxiNodes then return NumTaxiNodes() end
	if TaxiNumNodes then return TaxiNumNodes() end
	return 0
end

local function getCurrentTaxiNodeIndex()
	if not TaxiNodeGetType then return nil end
	local n = getNumTaxiNodes()
	if not n or n <= 0 then return nil end
	for i = 1, n do
		if TaxiNodeGetType(i) == "CURRENT" then
			return i
		end
	end
	return nil
end

local function getCurrentTaxiNodeName()
	if not TaxiNodeGetType or not TaxiNodeName then return nil end
	local i = getCurrentTaxiNodeIndex()
	if not i then return nil end
	return cleanTaxiName(TaxiNodeName(i))
end

local function buildRouteIndexFor(data, faction, continent)
	-- Build an index from startCoord -> endCoord -> duration from the routeString table.
	-- This avoids needing hop APIs (GetNumRoutes/TaxiGetNodeSlot) and works from just start+dest coords.
	if not (data and faction and continent) then return nil end
	local contData = data[faction] and data[faction][continent]
	if not contData then return nil end

	M._routeIndex = M._routeIndex or {}
	M._routeIndex[faction] = M._routeIndex[faction] or {}
	if M._routeIndex[faction][continent] then return M._routeIndex[faction][continent] end

	local idx = {}
	for route, dur in pairs(contData) do
		if type(route) == "string" and type(dur) == "number" and dur > 0 then
			local first1, first2
			local prev2, prev1
			for token in route:gmatch("[^:]+") do
				if not first1 then
					first1 = token
				elseif not first2 then
					first2 = token
				end
				prev2, prev1 = prev1, token
			end
			if first1 and first2 and prev2 and prev1 then
				local startCoord = first1 .. ":" .. first2
				local endCoord = prev2 .. ":" .. prev1
				local t = idx[startCoord]
				if not t then
					t = {}
					idx[startCoord] = t
				end
				-- Prefer the smaller time if duplicates exist.
				local cur = t[endCoord]
				if not cur or dur < cur then
					t[endCoord] = dur
				end
			end
		end
	end

	M._routeIndex[faction][continent] = idx
	return idx
end

local function getBuiltInDuration(destIndex)
	if not TaxiNodePosition then return nil end
	local data = HUI and HUI.flightData
	if not data then return nil end
	local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
	if not faction then return nil end
	local continent = getContinent()
	if not continent then return nil end

	local curIndex = getCurrentTaxiNodeIndex()
	if not curIndex then return nil end

	local sx, sy = TaxiNodePosition(curIndex)
	local startCoord = formatPos(sx, sy)
	local ex, ey = TaxiNodePosition(destIndex)
	local endCoord = formatPos(ex, ey)
	if not (startCoord and endCoord) then return nil end

	local idx = buildRouteIndexFor(data, faction, continent)
	if not idx then return nil end
	local m = idx[startCoord]
	if not m then return nil end
	return m[endCoord]
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
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
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
			self._bar:SetMinMaxValues(0, self._duration)
			self._bar:SetValue(math.min(self._duration, self._elapsed))
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

	-- Avoid stale data from previous flights.
	-- Resolve destination if we have a pending slot (should always be known on takeoff).
	if (not M._destName) and M._destSlot and TaxiNodeName then
		M._destName = cleanTaxiName(TaxiNodeName(M._destSlot))
	end
	local destName = M._destName
	if not destName or destName == "" then
		-- If this ever happens, it means we missed TakeTaxiNode; avoid showing a misleading label.
		return
	end
	if M._startFrom == nil then
		M._startFrom = getCurrentTaxiNodeName()
			or (GetMinimapZoneText and GetMinimapZoneText())
			or (GetRealZoneText and GetRealZoneText())
			or ""
	end
	if M._destDuration == nil then
		local db = getRouteDB()
		if db and M._startFrom and destName then
			local key = routeKey(M._startFrom, destName)
			M._destDuration = tonumber(db[key] or 0) or 0
		else
			M._destDuration = 0
		end
	end

	f._startTime = GetTime() or 0
	f._timeText:SetText("00:00")
	f._destText:SetText(destName or "")
	f._duration = M._destDuration or 0
	-- Initial visual mode.
	if f._duration and f._duration > 0 then
		f._bgShown = true
		f:SetBackdropColor(unpack(COLOR_BG))
		f:SetBackdropBorderColor(unpack(COLOR_BORDER))
		if f._bar and f._bar.Show then
			f._bar:Show()
			f._bar:SetMinMaxValues(0, f._duration)
			f._bar:SetValue(0)
		end
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
	M._destSlot = nil
	M._destDuration = nil
	M._startFrom = nil
	M._pendingUntil = nil
end

local function hideFrameOnly()
	if M._f then M._f:Hide() end
end

local function refresh()
	local now = GetTime and GetTime() or 0
	local pending = M._pendingUntil and now < M._pendingUntil
	if UnitOnTaxi and UnitOnTaxi("player") then
		if not (M._f and M._f:IsShown()) then
			show()
		end
		return
	end

	-- Waiting for taxi takeoff: keep data, but do not show the bar yet.
	if pending then
		if M._f and M._f:IsShown() then hideFrameOnly() end
		return
	end

	hide()
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
			M._destSlot = slot
			local name = TaxiNodeName and TaxiNodeName(slot) or nil
			M._destName = cleanTaxiName(name) or "In Flight"
			M._startFrom = getCurrentTaxiNodeName()
				or (GetMinimapZoneText and GetMinimapZoneText())
				or (GetRealZoneText and GetRealZoneText())
				or ""

			-- Known duration from built-in DB; also seed SavedVariables for display outside of taxi map state.
			local db = getRouteDB()
			local dur = getBuiltInDuration(slot)
			if db then
				local key = routeKey(M._startFrom, M._destName)
				M._destDuration = tonumber(dur or db[key] or 0) or 0
				if dur and dur > 0 then
					db[key] = dur
				end
			else
				M._destDuration = tonumber(dur or 0) or 0
			end

			-- Taxi takeoff can lag a bit; keep our data around, but don't show until we're actually on taxi.
			M._pendingUntil = (GetTime and GetTime() or 0) + 5

			-- If the taxi didn't actually start (e.g. not enough money), clear the pending state.
			if C_Timer and C_Timer.After then
				C_Timer.After(1.0, function()
					if M._pendingUntil and not (UnitOnTaxi and UnitOnTaxi("player")) then
						hide()
					end
				end)
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
			M._pendingUntil = nil
			show()
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

	-- Safety net: taxi events can be flaky; keep the display in sync.
	if not M._ticker and C_Timer and C_Timer.NewTicker then
		M._ticker = C_Timer.NewTicker(0.25, refresh)
	end

	refresh()
end

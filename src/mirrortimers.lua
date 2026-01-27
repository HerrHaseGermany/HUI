local _, HUI = ...
local U = HUI.util

local M = { name = "mirrortimers" }
table.insert(HUI.modules, M)

-- Hardcoded layout
local POINT, RELPOINT = "CENTER", "CENTER"
local X, Y = 0, 160
local BAR_W, BAR_H = 300, 20
local GAP_Y = 2
local FONT_SIZE = 12

local BAR_TEX = "Interface\\TARGETINGFRAME\\UI-StatusBar"

local COLORS = {
	BREATH = { 0.10, 0.75, 1.00, 1 },      -- light blue
	EXHAUSTION = { 1.00, 0.85, 0.10, 1 },  -- yellow (fatigue/exhaustion)
	FEIGNDEATH = { 0.10, 0.55, 0.20, 1 },  -- dark green
}

local active = {} -- [timer] = { endTime, duration, scale, paused, label }
local order = {}  -- timers in display order

local function now()
	return (GetTime and GetTime()) or 0
end

local function fmt(seconds)
	seconds = math.max(0, math.floor((seconds or 0) + 0.5))
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	if m > 0 then
		return string.format("%d:%02d", m, s)
	end
	return string.format("%d", s)
end

local function ensure()
	if M._f then return end

	local f = CreateFrame("Frame", "HUI_MirrorTimers", UIParent)
	f:SetSize(BAR_W, (BAR_H * 3) + (GAP_Y * 2))
	f:SetPoint(POINT, UIParent, RELPOINT, X, Y)
	f:Hide()
	M._f = f

	M._bars = {}
	for i = 1, 3 do
		local b = CreateFrame("StatusBar", nil, f, "BackdropTemplate")
		b:SetSize(BAR_W, BAR_H)
		b:SetStatusBarTexture(BAR_TEX)
		b:SetMinMaxValues(0, 1)
		b:SetValue(0)
		b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
		b:SetBackdropColor(0, 0, 0, 0.55)
		b:SetBackdropBorderColor(0, 0, 0, 1)

		if i == 1 then
			b:SetPoint("TOP", f, "TOP", 0, 0)
		else
			b:SetPoint("TOP", M._bars[i - 1], "BOTTOM", 0, -GAP_Y)
		end

			local label = U.Font(b, FONT_SIZE, true)
			if label.SetFont then label:SetFont(STANDARD_TEXT_FONT, FONT_SIZE, "THICKOUTLINE") end
			label:SetPoint("LEFT", b, "LEFT", 4, 0)
			label:SetJustifyH("LEFT")
			label:SetText("")
			b._label = label

			local timeText = U.Font(b, FONT_SIZE, true)
			if timeText.SetFont then timeText:SetFont(STANDARD_TEXT_FONT, FONT_SIZE, "THICKOUTLINE") end
			timeText:SetPoint("RIGHT", b, "RIGHT", -4, 0)
			timeText:SetJustifyH("RIGHT")
			timeText:SetText("")
			b._time = timeText

		b:Hide()
		M._bars[i] = b
	end

	f:SetScript("OnUpdate", function()
		if not next(active) then
			f:Hide()
			return
		end

		local t = now()
		local changed = false
		for timer, st in pairs(active) do
			if not st.paused and st.endTime and t >= st.endTime then
				active[timer] = nil
				changed = true
			end
		end
		if changed then
			order = {}
			for timer in pairs(active) do order[#order + 1] = timer end
		end

		-- Sort: stable-ish by remaining time (shorter first).
		table.sort(order, function(a, b)
			local ra = active[a] and (active[a].endTime - t) or 0
			local rb = active[b] and (active[b].endTime - t) or 0
			return ra < rb
		end)

		for i = 1, 3 do
			local bar = M._bars[i]
			local timer = order[i]
			local st = timer and active[timer]
			if bar and st then
				local remain = st.paused and (st.remaining or 0) or math.max(0, (st.endTime or t) - t)
				local dur = st.duration or 1
				bar:SetMinMaxValues(0, dur)
				bar:SetValue(remain)
				local col = COLORS[timer]
				if col then
					bar:SetStatusBarColor(col[1], col[2], col[3], col[4] or 1)
				else
					bar:SetStatusBarColor(1, 1, 1, 1)
				end
				bar._label:SetText(st.label or timer)
				bar._time:SetText(fmt(remain))
				bar:Show()
			elseif bar then
				bar:Hide()
			end
		end

		f:Show()
	end)
end

local function hideBlizzard()
	-- Classic uses MirrorTimerContainer; some clients still have MirrorTimer1..3.
	local c = _G.MirrorTimerContainer
	if c and c.Hide then
		c:Hide()
		if c.UnregisterAllEvents then c:UnregisterAllEvents() end
		if c.SetScript then c:SetScript("OnShow", function(self) self:Hide() end) end
	end

	for i = 1, 3 do
		local mt = _G["MirrorTimer" .. i]
		if mt and mt.Hide then
			mt:Hide()
			if mt.UnregisterAllEvents then mt:UnregisterAllEvents() end
			if mt.SetScript then mt:SetScript("OnShow", function(self) self:Hide() end) end
		end
	end
end

local function onStart(timer, value, maxvalue, scale, paused, label)
	ensure()
	if not timer then return end
	-- Blizzard passes milliseconds; `scale` is typically -1 for countdown.
	local s = math.abs(scale or 1)
	local dur = (maxvalue or 0) / (s * 1000)
	local remain = (value or 0) / (s * 1000)
	local isPaused = (paused == 1) or (paused == true)

	active[timer] = {
		duration = dur > 0 and dur or 1,
		endTime = (not isPaused) and (now() + remain) or nil,
		scale = scale,
		paused = isPaused,
		remaining = isPaused and remain or nil,
		label = label,
	}

	-- Ensure it exists in ordering list.
	local seen = false
	for _, t in ipairs(order) do if t == timer then seen = true break end end
	if not seen then order[#order + 1] = timer end

	-- Hidden frames don't run OnUpdate; ensure the container is visible when a timer starts.
	if M._f and M._f.Show then M._f:Show() end
end

local function onStop(timer)
	if not timer then return end
	active[timer] = nil
	if M._f and not next(active) then M._f:Hide() end
end

local function onPause(timer, paused, value)
	local st = timer and active[timer]
	if not st then return end
	local isPaused = (paused == 1) or (paused == true)
	if isPaused then
		st.paused = true
		-- Some clients send `value` (ms) on pause; prefer it if available.
		if value ~= nil then
			local s = math.abs(st.scale or 1)
			st.remaining = (value or 0) / (s * 1000)
		else
			st.remaining = math.max(0, (st.endTime or now()) - now())
		end
		st.endTime = nil
	else
		st.paused = false
		local rem = st.remaining or 0
		st.endTime = now() + rem
		st.remaining = nil
	end

	if M._f and M._f.Show then M._f:Show() end
end

function M:Apply()
	ensure()
	hideBlizzard()

	if not M._ev then
		local ev = CreateFrame("Frame")
		M._ev = ev
		ev:RegisterEvent("PLAYER_ENTERING_WORLD")
		ev:RegisterEvent("MIRROR_TIMER_START")
		ev:RegisterEvent("MIRROR_TIMER_STOP")
		ev:RegisterEvent("MIRROR_TIMER_PAUSE")
		ev:SetScript("OnEvent", function(_, event, ...)
			if event == "PLAYER_ENTERING_WORLD" then
				hideBlizzard()
			elseif event == "MIRROR_TIMER_START" then
				onStart(...)
			elseif event == "MIRROR_TIMER_STOP" then
				onStop(...)
			elseif event == "MIRROR_TIMER_PAUSE" then
				onPause(...)
			end
		end)
	end
end

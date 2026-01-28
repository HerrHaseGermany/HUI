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

-- NOTE: Mirror timers can count down (scale < 0) or fill up (scale > 0).
-- Blizzard's implementation tracks a "value" in milliseconds and updates it
-- as: value = value + elapsed * 1000 * scale.
local active = {} -- [timer] = { valueMs, maxMs, scale, paused, label }
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

	f:SetScript("OnUpdate", function(_, elapsed)
		if not next(active) then
			f:Hide()
			return
		end

		local dt = elapsed or 0
		local changed = false
		for timer, st in pairs(active) do
			if not st.paused then
				local scale = st.scale or -1
				local maxMs = st.maxMs or 0
				local v = (st.valueMs or 0) + (dt * 1000 * scale)
				st.valueMs = v

				if (scale < 0 and v <= 0) or (scale > 0 and v >= maxMs) then
					active[timer] = nil
					changed = true
				end
			end
		end
		if changed then
			order = {}
			for timer in pairs(active) do order[#order + 1] = timer end
		end

		-- Sort: stable-ish by remaining time (shorter first).
		local t = now()
		table.sort(order, function(a, b)
			local sa = active[a]
			local sb = active[b]

			local function remainingSeconds(st)
				if not st then return 0 end
				local scale = st.scale or -1
				local maxMs = st.maxMs or 0
				local v = st.valueMs or 0
				local remainMs = (scale < 0) and v or (maxMs - v)
				return (remainMs or 0) / 1000
			end

			local ra = remainingSeconds(sa)
			local rb = remainingSeconds(sb)
			return ra < rb
		end)

		for i = 1, 3 do
			local bar = M._bars[i]
			local timer = order[i]
			local st = timer and active[timer]
			if bar and st then
				local maxMs = st.maxMs or 1
				local vMs = st.valueMs or 0
				local maxSec = maxMs / 1000
				local vSec = vMs / 1000

				bar:SetMinMaxValues(0, maxSec > 0 and maxSec or 1)
				bar:SetValue(math.max(0, math.min(maxSec, vSec)))
				local col = COLORS[timer]
				if col then
					bar:SetStatusBarColor(col[1], col[2], col[3], col[4] or 1)
				else
					bar:SetStatusBarColor(1, 1, 1, 1)
				end
				bar._label:SetText(st.label or timer)
				local scale = st.scale or -1
				local remainSec = (scale < 0) and (vSec) or math.max(0, (maxSec - vSec))
				bar._time:SetText(fmt(remainSec))
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
	local isPaused = (paused == 1) or (paused == true)

	active[timer] = {
		valueMs = value or 0,
		maxMs = maxvalue or 0,
		scale = scale,
		paused = isPaused,
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
		if value ~= nil then st.valueMs = value or 0 end
	else
		st.paused = false
		if value ~= nil then st.valueMs = value or 0 end
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

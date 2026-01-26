local _, HUI = ...
local U = HUI.util

local M = { name = "xpbar" }
table.insert(HUI.modules, M)

-- Hardcoded layout
local XPBAR_H = 20
local XPBAR_Y = 0
local XPBAR_SCALE = 1

-- Colors
local COLOR_XP = { 0.58, 0.00, 0.55, 1 } -- current xp
local COLOR_RESTED = { 0.10, 0.55, 1.00, 0.9 }
local COLOR_XP_RESTED = { 0.10, 0.55, 1.00, 1 } -- blue tint when any rested XP exists
local COLOR_QUEST_DONE = { 0.10, 0.85, 0.10, 0.9 } -- completed (not turned in)
local COLOR_QUEST_LOG = { 1.00, 0.85, 0.10, 0.9 } -- in log (not completed)
local COLOR_BG = { 0, 0, 0, 0.55 }
local COLOR_BORDER = { 0, 0, 0, 1 }

local GetNumQuestLogEntries_ = (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) or GetNumQuestLogEntries
local GetQuestIDForLogIndex_ = (C_QuestLog and C_QuestLog.GetQuestIDForLogIndex) or function(i)
	return select(8, GetQuestLogTitle(i))
end
local IsQuestComplete_ = (C_QuestLog and C_QuestLog.IsComplete) or IsQuestComplete
local QuestReadyForTurnIn_ = (C_QuestLog and C_QuestLog.ReadyForTurnIn) or function() return false end

local function colorToHex(c)
	local r = math.floor((c[1] or 1) * 255 + 0.5)
	local g = math.floor((c[2] or 1) * 255 + 0.5)
	local b = math.floor((c[3] or 1) * 255 + 0.5)
	return string.format("%02x%02x%02x", r, g, b)
end

local function hexRGB(r, g, b)
	r = math.floor((r or 1) * 255 + 0.5)
	g = math.floor((g or 1) * 255 + 0.5)
	b = math.floor((b or 1) * 255 + 0.5)
	return string.format("%02x%02x%02x", r, g, b)
end

local function qualityColorHighGood(value, redMax, yellowMax)
	if value <= redMax then
		return hexRGB(1.00, 0.20, 0.20) -- red
	end
	if value <= yellowMax then
		return hexRGB(1.00, 0.85, 0.10) -- yellow
	end
	return hexRGB(0.20, 1.00, 0.20) -- green
end

local function qualityColorLowGood(value, greenMax, yellowMax)
	if value <= greenMax then
		return hexRGB(0.20, 1.00, 0.20) -- green
	end
	if value <= yellowMax then
		return hexRGB(1.00, 0.85, 0.10) -- yellow
	end
	return hexRGB(1.00, 0.20, 0.20) -- red
end

local function formatHMS(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %02dm %02ds", h, m, s)
	end
	if m > 0 then
		return string.format("%dm %02ds", m, s)
	end
	return string.format("%ds", s)
end

local function clamp(v, minV, maxV)
	if v < minV then return minV end
	if v > maxV then return maxV end
	return v
end

local function safeSetWidth(f, w)
	if not f or not f.SetWidth then return end
	f:SetWidth(math.max(0, w or 0))
end

local function medianLast10(values, tmp)
	local n = values and #values or 0
	if n <= 0 then return 0 end
	tmp = tmp or {}
	for i = 1, n do
		tmp[i] = values[i]
	end
	for i = n + 1, #tmp do
		tmp[i] = nil
	end
	table.sort(tmp)
	local mid = math.floor((n + 1) / 2)
	if (n % 2) == 1 then
		return tmp[mid] or 0
	end
	local a = tmp[mid] or 0
	local b = tmp[mid + 1] or 0
	return math.floor((a + b) / 2)
end

local function formatGrindEstimate(killMedianXP, remainingXP, sampleCount)
	if killMedianXP and killMedianXP > 0 and remainingXP and remainingXP > 0 then
		local mobs = math.ceil(remainingXP / killMedianXP)
		return string.format("Grind: %d mobs @ %dxp", mobs, killMedianXP)
	end
	if remainingXP and remainingXP > 0 then
		return string.format("Start grind for data", sampleCount or 0)
	end
	return ""
end

local function escapeLuaPattern(s)
	return (s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function buildPatternsFromGlobal(fmt)
	if type(fmt) ~= "string" or fmt == "" then return nil end
	local p = escapeLuaPattern(fmt)
	p = p:gsub("%%%%d", "(%%d+)")
	p = p:gsub("%%%%s", ".+")
	p = p:gsub("%%%%%.%d?f", "%%d+%.?%%d*")
	return "^" .. p .. "$"
end

function M:_EnsureXPGainPatterns()
	if M._xpGainPatterns then return end
	local candidates = {
		_G.COMBATLOG_XPGAIN_FIRSTPERSON,
		_G.COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED,
		_G.COMBATLOG_XPGAIN_FIRSTPERSON_GROUP,
		_G.COMBATLOG_XPGAIN_FIRSTPERSON_RAID,
		_G.COMBATLOG_XPGAIN_FIRSTPERSON_RAID_UNNAMED,
	}
	local pats = {}
	for _, fmt in ipairs(candidates) do
		local pat = buildPatternsFromGlobal(fmt)
		if pat then
			pats[#pats + 1] = pat
		end
	end
	M._xpGainPatterns = pats
end

local function ensure()
	if M._f then return end

	local f = CreateFrame("Frame", "HUI_XPBar", UIParent, "BackdropTemplate")
	f:SetFrameStrata("LOW")
	f:SetToplevel(false)
	f:SetHeight(XPBAR_H)
	f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, XPBAR_Y)
	f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, XPBAR_Y)
	f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	f:SetBackdropColor(unpack(COLOR_BG))
	f:SetBackdropBorderColor(unpack(COLOR_BORDER))
	f:SetScale(XPBAR_SCALE)

	-- Secondary info bar above the XP bar (background only for now).
	local info = CreateFrame("Frame", "HUI_XPInfoBar", UIParent, "BackdropTemplate")
	info:SetFrameStrata("LOW")
	info:SetToplevel(false)
	info:SetHeight(XPBAR_H)
	info:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 0)
	info:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 0)
	info:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	info:SetBackdropColor(unpack(COLOR_BG))
	info:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
	info:SetScale(XPBAR_SCALE)
	f._infoBar = info
	M._info = info

	local bar = CreateFrame("StatusBar", nil, f)
	bar:SetAllPoints(f)
	bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	bar:SetStatusBarColor(unpack(COLOR_XP))
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	f._bar = bar

	-- Layering: background (frame backdrop) -> bars (statusbar + overlays) -> HUD overlay -> text
	-- Put HUD overlay on the statusbar so it always draws above the fills.
	local overlay = bar:CreateTexture(nil, "OVERLAY", nil, 0)
	if overlay.SetAtlas then
		overlay:SetAtlas("hud-MainMenuBar-experiencebar-large-single", true)
	else
		overlay:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
		overlay:SetVertexColor(1, 1, 1, 1)
	end
	overlay:SetAlpha(0.9)
	overlay:SetAllPoints(bar)
	f._hudOverlay = overlay

	local overlayDone = bar:CreateTexture(nil, "ARTWORK", nil, 1)
	overlayDone:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	overlayDone:SetVertexColor(unpack(COLOR_QUEST_DONE))
	overlayDone:SetPoint("TOPLEFT", bar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
	overlayDone:SetPoint("BOTTOMLEFT", bar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
	overlayDone:SetWidth(0)
	f._overlayDone = overlayDone

	local overlayLog = bar:CreateTexture(nil, "ARTWORK", nil, 2)
	overlayLog:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	overlayLog:SetVertexColor(unpack(COLOR_QUEST_LOG))
	overlayLog:SetPoint("TOPLEFT", overlayDone, "TOPRIGHT", 0, 0)
	overlayLog:SetPoint("BOTTOMLEFT", overlayDone, "BOTTOMRIGHT", 0, 0)
	overlayLog:SetWidth(0)
	f._overlayLog = overlayLog

	local overlayRest = bar:CreateTexture(nil, "ARTWORK", nil, 3)
	overlayRest:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	overlayRest:SetVertexColor(unpack(COLOR_RESTED))
	overlayRest:SetPoint("TOPLEFT", bar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
	overlayRest:SetPoint("BOTTOMLEFT", bar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
	overlayRest:SetWidth(0)
	f._overlayRest = overlayRest

	local txt = U.Font(bar, 12, true)
	if txt.SetFont then txt:SetFont(STANDARD_TEXT_FONT, 12, "THICKOUTLINE") end
	if txt.SetDrawLayer then txt:SetDrawLayer("OVERLAY", 10) end
	txt:SetPoint("CENTER", bar, "CENTER", 0, 0)
	txt:SetJustifyH("CENTER")
	txt:SetText("")
	f._text = txt

	local levelTxt = U.Font(bar, 12, true)
	if levelTxt.SetFont then levelTxt:SetFont(STANDARD_TEXT_FONT, 12, "THICKOUTLINE") end
	if levelTxt.SetDrawLayer then levelTxt:SetDrawLayer("OVERLAY", 10) end
	levelTxt:SetPoint("LEFT", bar, "LEFT", 15, 0)
	levelTxt:SetJustifyH("LEFT")
	levelTxt:SetText("")
	f._levelText = levelTxt

	local infoLeft = U.Font(info, 12, true)
	if infoLeft.SetFont then infoLeft:SetFont(STANDARD_TEXT_FONT, 12, "THICKOUTLINE") end
	infoLeft:SetPoint("LEFT", info, "LEFT", 15, 0)
	infoLeft:SetJustifyH("LEFT")
	infoLeft:SetText("")
	info._leftText = infoLeft

	local infoMid = U.Font(info, 12, true)
	if infoMid.SetFont then infoMid:SetFont(STANDARD_TEXT_FONT, 12, "THICKOUTLINE") end
	infoMid:SetPoint("CENTER", info, "CENTER", 0, 0)
	infoMid:SetJustifyH("CENTER")
	infoMid:SetText("")
	info._midText = infoMid

	local infoRight = U.Font(info, 12, true)
	if infoRight.SetFont then infoRight:SetFont(STANDARD_TEXT_FONT, 12, "THICKOUTLINE") end
	infoRight:SetPoint("RIGHT", info, "RIGHT", -6, 0)
	infoRight:SetJustifyH("RIGHT")
	infoRight:SetText("")
	info._rightText = infoRight

	f:SetScript("OnSizeChanged", function() if M.Update then M:Update() end end)

	M._f = f
end

local function sumQuestXP()
	if not GetNumQuestLogEntries_ or not GetQuestLogTitle or not GetQuestLogRewardXP then
		return 0, 0
	end
	local doneXP = 0
	local logXP = 0

	local prevSel = (GetQuestLogSelection and GetQuestLogSelection()) or 0

	local n = GetNumQuestLogEntries_()
	for i = 1, n do
		local title, _, _, _, isHeader = GetQuestLogTitle(i)
		if title and not isHeader then
			local questID = GetQuestIDForLogIndex_(i) or 0
			if questID and questID > 0 then
				-- On Classic, reward getters often require selecting the quest log entry first.
				if SelectQuestLogEntry then SelectQuestLogEntry(i) end

				local xp = 0
				-- Some versions expose questID-based reward getters, others are selection-based.
				if C_QuestLog and C_QuestLog.GetQuestLogRewardXP then
					xp = C_QuestLog.GetQuestLogRewardXP(questID) or 0
				else
					xp = GetQuestLogRewardXP() or 0
				end

				if xp > 0 then
					local complete = false
					if QuestReadyForTurnIn_ and QuestReadyForTurnIn_(questID) then
						complete = true
					elseif IsQuestComplete_ and IsQuestComplete_(questID) then
						complete = true
					end

					if complete then
						doneXP = doneXP + xp
					else
						logXP = logXP + xp
					end
				end
			end
		end
	end

	if prevSel and prevSel > 0 and SelectQuestLogEntry then
		SelectQuestLogEntry(prevSel)
	end

	return doneXP, logXP
end

function M:Update()
	ensure()
	local f = M._f
	if not f then return end

	local level = UnitLevel("player") or 0
	local maxLevel = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or _G.MAX_PLAYER_LEVEL or 60
	if level >= maxLevel then
		f:Hide()
		if f._infoBar then f._infoBar:Hide() end
		return
	end

	local maxXP = UnitXPMax("player") or 0
	local curXP = UnitXP("player") or 0
	if maxXP <= 0 then
		f:Hide()
		if f._infoBar then f._infoBar:Hide() end
		return
	end
	f:Show()
	if f._infoBar then f._infoBar:Show() end

	-- Keep "played this level" ticking even when TIME_PLAYED_MSG isn't firing.
	local playedSeconds = 0
	if M._playedLevelSeconds and M._playedLevelBaseTime then
		local elapsed = (GetTime and GetTime() or 0) - (M._playedLevelBaseTime or 0)
		playedSeconds = (M._playedLevelSeconds or 0) + elapsed
	end

	curXP = clamp(curXP, 0, maxXP)
	f._bar:SetMinMaxValues(0, maxXP)
	f._bar:SetValue(curXP)

	if f._levelText then
		f._levelText:SetText(string.format("%d => %d", level, level + 1))
	end

	local w = f:GetWidth() or 0
	local pxPerXP = (maxXP > 0 and w > 0) and (w / maxXP) or 0

	local doneXP, logXP = sumQuestXP()
	doneXP = clamp(doneXP, 0, maxXP - curXP)
	-- logXP excludes completed quests already; cap remaining space after doneXP.
	logXP = clamp(logXP, 0, maxXP - curXP - doneXP)

	local rested = (GetXPExhaustion and GetXPExhaustion()) or 0
	rested = clamp(rested, 0, maxXP - curXP)

	local wDone = doneXP * pxPerXP
	local wLog = logXP * pxPerXP
	local wRest = 0

	-- Re-anchor segments each update so "log" doesn't disappear when "done" is 0 (or hidden).
	local baseTex = f._bar:GetStatusBarTexture()
	if baseTex then
		if f._overlayDone then
			f._overlayDone:ClearAllPoints()
			f._overlayDone:SetPoint("TOPLEFT", baseTex, "TOPRIGHT", 0, 0)
			f._overlayDone:SetPoint("BOTTOMLEFT", baseTex, "BOTTOMRIGHT", 0, 0)
		end
		if f._overlayLog then
			f._overlayLog:ClearAllPoints()
			if wDone > 0.05 and f._overlayDone then
				f._overlayLog:SetPoint("TOPLEFT", f._overlayDone, "TOPRIGHT", 0, 0)
				f._overlayLog:SetPoint("BOTTOMLEFT", f._overlayDone, "BOTTOMRIGHT", 0, 0)
			else
				f._overlayLog:SetPoint("TOPLEFT", baseTex, "TOPRIGHT", 0, 0)
				f._overlayLog:SetPoint("BOTTOMLEFT", baseTex, "BOTTOMRIGHT", 0, 0)
			end
		end
		if f._overlayRest then
			f._overlayRest:ClearAllPoints()
			f._overlayRest:SetPoint("TOPLEFT", baseTex, "TOPRIGHT", 0, 0)
			f._overlayRest:SetPoint("BOTTOMLEFT", baseTex, "BOTTOMRIGHT", 0, 0)
		end
	end

	safeSetWidth(f._overlayDone, wDone)
	safeSetWidth(f._overlayLog, wLog)
	safeSetWidth(f._overlayRest, wRest)

	-- Some clients render a 1px sliver even at width 0; hide only when effectively zero.
	if f._overlayDone then f._overlayDone:SetShown(wDone > 0.05) end
	if f._overlayLog then f._overlayLog:SetShown(wLog > 0.05) end
	if f._overlayRest then f._overlayRest:Hide() end

	-- When any rested XP exists, tint the base XP fill blue; keep percent text as-is.
	if rested > 0 then
		f._bar:SetStatusBarColor(unpack(COLOR_XP_RESTED))
	else
		f._bar:SetStatusBarColor(unpack(COLOR_XP))
	end

	local info = f._infoBar
	if info and info._leftText then
		info._leftText:SetText(formatHMS(playedSeconds))
	end

	if info and info._midText then
		local pctXP = (curXP / maxXP) * 100
		local pctDone = (doneXP / maxXP) * 100
		local pctLog = (logXP / maxXP) * 100
		local pctRest = (rested / maxXP) * 100
		local pctTotal = ((curXP + doneXP + logXP + rested) / maxXP) * 100

		local cXP = colorToHex(COLOR_XP)
		local cDone = colorToHex(COLOR_QUEST_DONE)
		local cLog = colorToHex(COLOR_QUEST_LOG)
		local cRest = colorToHex(COLOR_RESTED)

		local mid = string.format(
			"|cff%sXP %.1f%%|r  |cff%sDone %.1f%%|r  |cff%sLog %.1f%%|r  |cff%sRest %.1f%%|r  (%.1f%%)",
			cXP, pctXP, cDone, pctDone, cLog, pctLog, cRest, pctRest, pctTotal
		)

		local remainingXP = maxXP - curXP
		if not M._killXPTmp then M._killXPTmp = {} end
		local n = M._killXP and #M._killXP or 0
		local med = medianLast10(M._killXP, M._killXPTmp)
		local grind = formatGrindEstimate(med, remainingXP, n)
		if grind and grind ~= "" then
			mid = mid .. "  |  " .. grind
		end
		info._midText:SetText(mid)
	end

	if info and info._rightText then
		local fps = (GetFramerate and GetFramerate()) or 0
		local latencyHome, latencyWorld = 0, 0
		if GetNetStats then
			local _, _, home, world = GetNetStats()
			latencyHome = home or 0
			latencyWorld = world or 0
		end
		local lat = math.max(latencyHome, latencyWorld)
		local fpsHex = qualityColorHighGood(fps, 29, 59) -- red <=29, yellow <=59, else green
		local latHex = qualityColorLowGood(lat, 60, 120) -- green <=60, yellow <=120, else red
		info._rightText:SetText(string.format("|cff%s%.0f|r fps  |cff%s%d|r ms", fpsHex, fps, latHex, lat))
	end

	if f._text then f._text:SetText("") end
end

function M:AddKillXP(xp)
	if not xp or xp <= 0 then return end
	local t = M._killXP
	if not t then
		t = {}
		M._killXP = t
	end
	local n = #t
	if n < 10 then
		t[n + 1] = xp
	else
		for i = 1, 9 do
			t[i] = t[i + 1]
		end
		t[10] = xp
	end
end

function M:ParseKillXPFromMessage(msg)
	if type(msg) ~= "string" or msg == "" then return 0 end

	M:_EnsureXPGainPatterns()
	local patterns = M._xpGainPatterns
	if patterns then
		for i = 1, #patterns do
			local a, b, c = msg:match(patterns[i])
			if a then
				local xp = tonumber(a) or 0
				if b then xp = xp + (tonumber(b) or 0) end
				if c then xp = xp + (tonumber(c) or 0) end
				return xp
			end
		end
	end

	local a, b = msg:match("(%d+).-%+(%d+)")
	if a and b then
		return (tonumber(a) or 0) + (tonumber(b) or 0)
	end
	return tonumber(msg:match("(%d+)")) or 0
end

function M:Apply()
	ensure()
	if not M._ev then
		local ev = CreateFrame("Frame")
		M._ev = ev
		ev:RegisterEvent("PLAYER_ENTERING_WORLD")
		ev:RegisterEvent("PLAYER_XP_UPDATE")
		ev:RegisterEvent("UPDATE_EXHAUSTION")
		ev:RegisterEvent("PLAYER_LEVEL_UP")
		ev:RegisterEvent("TIME_PLAYED_MSG")
		ev:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
		ev:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		ev:RegisterEvent("QUEST_LOG_UPDATE")
		ev:RegisterEvent("QUEST_ACCEPTED")
		ev:RegisterEvent("QUEST_TURNED_IN")
		ev:SetScript("OnEvent", function(_, event, ...)
			if event == "COMBAT_LOG_EVENT_UNFILTERED" then
				if not CombatLogGetCurrentEventInfo then return end
				local _, subevent = CombatLogGetCurrentEventInfo()
				if subevent == "PARTY_KILL" then
					M._pendingKillXP = true
					M._pendingKillXPBase = UnitXP("player") or 0
					M._pendingKillXPMax = UnitXPMax("player") or 0
				end
				return
			end

			if event == "TIME_PLAYED_MSG" then
				local _, levelTime = ...
				M._playedLevelSeconds = levelTime or 0
				M._playedLevelBaseTime = GetTime and GetTime() or 0
			elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LEVEL_UP" then
				M._playedLevelSeconds = 0
				M._playedLevelBaseTime = GetTime and GetTime() or 0
				M._killXP = nil
				M._xpGainPatterns = nil
				M:_EnsureXPGainPatterns()
				M._pendingKillXP = nil
				M._pendingKillXPBase = nil
				M._pendingKillXPMax = nil
				-- Slight delay tends to make TIME_PLAYED_MSG more reliable on Classic.
				if C_Timer and C_Timer.NewTimer and RequestTimePlayed then
					C_Timer.NewTimer(0.5, function() RequestTimePlayed() end)
				elseif RequestTimePlayed then
					RequestTimePlayed()
				end
			elseif event == "PLAYER_XP_UPDATE" then
				if M._pendingKillXP then
					local base = M._pendingKillXPBase or 0
					local baseMax = M._pendingKillXPMax or 0
					local now = UnitXP("player") or 0
					local gain = now - base
					if gain < 0 and baseMax > 0 then
						gain = now + (baseMax - base)
					end
					if gain > 0 then
						M:AddKillXP(gain)
					end
					M._pendingKillXP = nil
					M._pendingKillXPBase = nil
					M._pendingKillXPMax = nil
				end
			elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
				local msg = ...
				M:AddKillXP(M:ParseKillXPFromMessage(msg))
			end
			M:Update()
		end)
	end
	if not M._ticker and C_Timer and C_Timer.NewTicker then
		M._ticker = C_Timer.NewTicker(0.25, function()
			if M.Update then M:Update() end
		end)
	end
	if RequestTimePlayed then RequestTimePlayed() end
	M:Update()
end

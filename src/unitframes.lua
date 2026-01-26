local _, HUI = ...
local U = HUI.util

local M = { name = "unitframes" }
tinsert(HUI.modules, M)

-- Hardcoded layout (no options / no saved positioning).
local PLAYER_X = 0
local PLAYER_Y = -200
local PLAYER_W = 350
local GAP = 0
local HEALTH_H = 30
local POWER_H = 20
local CAST_H = 20
local PET_HEALTH_H = 20
local PET_POWER_H = 15

-- Per-bar font tuning
local HEALTH_TEXT_SIZE_DELTA = 2
local PET_POWER_TEXT_SIZE_DELTA = -2

-- Target frame (hardcoded)
local TARGET_X = 0
local TARGET_Y = 400
local TARGET_W = 400
local TARGET_NAME_H = 24
local TARGET_NAME_FONT_SIZE = 20
local TARGET_HEALTH_H = 30
local TARGET_POWER_H = 20
local TARGET_CAST_H = 20
local TARGET_GAP = 0
local TARGET_NAME_GAP = 2
local TARGET_MODEL_W = 80
local TARGET_MODEL_H = 80
local TARGET_MODEL_GAP = 0
local TARGET_MODEL_PORTRAIT_ZOOM = 1
local TARGET_MODEL_CAM_DISTANCE = 1
local TARGET_RAIDMARK_SIZE = 36
local TARGET_COMBO_OFFSET_Y = -60

-- TargetTarget frame (hardcoded)
local TOT_BAR_W = 20
local TOT_HEALTH_H = 80
local TOT_POWER_H = 80
local TOT_BAR_GAP = 0
local TOT_OFFSET_X = 6
local TOT_MODEL_W = 80
local TOT_MODEL_H = 80
local TOT_MODEL_GAP = 0
local TOT_MODEL_PORTRAIT_ZOOM = 1
local TOT_MODEL_CAM_DISTANCE = 1
local TOT_NAME_FONT_SIZE = 12
local TOT_NAME_GAP = 4

-- Level badge tuning (background/frame can be sized/positioned independently)
local LEVEL_BADGE_W = 50
local LEVEL_BADGE_H = 50
local LEVEL_BADGE_X = 0
local LEVEL_BADGE_Y = 0

local LEVEL_BG_W = 50
local LEVEL_BG_H = 50
local LEVEL_BG_X = 0
local LEVEL_BG_Y = -2

local LEVEL_FRAME_W = 60
local LEVEL_FRAME_H = 60
local LEVEL_FRAME_X = 0.5
local LEVEL_FRAME_Y = 0

local LEVEL_FONT_SIZE = 20
-- 0 = no desaturation, 1 = fully gray
local LEVEL_FRAME_DESAT_BELOW_MAX = 0.0000001
local LEVEL_FRAME_DESAT_AT_MAX = 0.0

-- PvP badge (left of level badge)
local PVP_BADGE_W = 80
local PVP_BADGE_H = 80
-- Negative values push the PvP badge towards the level badge (to the right).
local PVP_BADGE_GAP = -50
-- PvP timer (above the PvP badge for player)
local PVP_TIMER_FONT_SIZE = 10
local PVP_TIMER_OFFSET_X = -13
local PVP_TIMER_OFFSET_Y = -3
local PVP_TIMER_COLOR_R = 1
local PVP_TIMER_COLOR_G = 1
local PVP_TIMER_COLOR_B = 0.2

-- Auras (hardcoded "options")
local AURA_SIZE = 40
local AURA_FONT_SIZE = 16
local AURA_GAP = 4
local AURA_SPACER = 14
local AURA_MAX_BUFFS = 40
local AURA_MAX_DEBUFFS = 24
local AURA_BORDER_SIZE = 1
local AURA_POS_X = 0
local AURA_POS_Y = -110

-- Target auras (hardcoded)
local TARGET_AURA_SIZE = 40
local TARGET_AURA_FONT_SIZE = 16
local TARGET_AURA_GAP = 4
local TARGET_AURA_SPACER = 14
local TARGET_AURA_MAX_BUFFS = 24
local TARGET_AURA_MAX_DEBUFFS = 24
local TARGET_AURA_BORDER_SIZE = 1
local TARGET_AURA_POS_X = 0
local TARGET_AURA_POS_Y = -70

local function isHardcore()
	if C_GameRules and C_GameRules.IsHardcoreActive then
		return C_GameRules.IsHardcoreActive() and true or false
	end
	if C_ClassicHardcore and C_ClassicHardcore.IsHardcoreActive then
		return C_ClassicHardcore.IsHardcoreActive() and true or false
	end
	return false
end

-- PvP timer tracking:
-- Some Classic builds can report a non-zero GetPVPTimer() on login and not update it reliably.
-- Track the timer ourselves once observed so it can count down to 0 without requiring an event.
local _huiPvPTimerStart
local _huiPvPTimerMs

local function pvpTimerRemainingMs()
	if not GetPVPTimer then return 0 end

	local now = GetTime and GetTime() or 0
	local cachedRemaining = 0
	if _huiPvPTimerStart and _huiPvPTimerMs then
		cachedRemaining = _huiPvPTimerMs - ((now - _huiPvPTimerStart) * 1000)
		if cachedRemaining < 0 then cachedRemaining = 0 end
	end

	local t = GetPVPTimer()
	if type(t) ~= "number" or t <= 0 or t > 310000 then
		_huiPvPTimerStart, _huiPvPTimerMs = nil, nil
		return 0
	end

	-- Only "re-seed" the timer when it meaningfully increases (re-flagging), otherwise
	-- keep counting down from our cached start to avoid a stuck constant value.
	if not _huiPvPTimerStart or (t > cachedRemaining + 1000) then
		_huiPvPTimerStart = now
		_huiPvPTimerMs = t
		return t
	end

	return cachedRemaining
end

local function getMaxPlayerLevel()
	if GetMaxPlayerLevel then
		local v = GetMaxPlayerLevel()
		if type(v) == "number" and v > 0 then return v end
	end
	if MAX_PLAYER_LEVEL and type(MAX_PLAYER_LEVEL) == "number" and MAX_PLAYER_LEVEL > 0 then
		return MAX_PLAYER_LEVEL
	end
	return 60
end

local function setShown(frame, shown)
	if not frame or type(frame) ~= "table" or not frame.Show or not frame.Hide then return end
	if shown then
		frame:Show()
	else
		frame:Hide()
	end
end

local function hideBlizzardAurasAndCastbar()
	-- Buffs/Debuffs
	if _G.BuffFrame then _G.BuffFrame:Hide() end
	if _G.DebuffFrame then _G.DebuffFrame:Hide() end

	-- Castbars
	if U and U.UnregisterAndHide then
		U.UnregisterAndHide(_G.CastingBarFrame)
		U.UnregisterAndHide(_G.PetCastingBarFrame)
	else
		if _G.CastingBarFrame then _G.CastingBarFrame:Hide() end
		if _G.PetCastingBarFrame then _G.PetCastingBarFrame:Hide() end
	end

	-- TargetFrameSpellBar is tightly coupled to Blizzard targetframe layout; unregistering or reparenting it
	-- can break TargetFrame.lua during login. Keep it intact but force it hidden.
	if _G.TargetFrameSpellBar then
		_G.TargetFrameSpellBar.showCastbar = false
		_G.TargetFrameSpellBar:Hide()
		_G.TargetFrameSpellBar:SetScript("OnShow", function(self) self:Hide() end)
	end
end

local function forceHide(frame)
	if not frame or not frame.Hide then return end
	frame:Hide()
	-- Keep Blizzard code intact but prevent it from showing again.
	if frame.SetScript then
		frame:SetScript("OnShow", function(self) self:Hide() end)
	end
end

local function shortNumber(n)
	if not n then return "0" end
	if n >= 1e6 then
		return string.format("%.1fm", n / 1e6):gsub("%.0m", "m")
	end
	if n >= 1e3 then
		return string.format("%.1fk", n / 1e3):gsub("%.0k", "k")
	end
	return tostring(math.floor(n + 0.5))
end

local function formatHealth(cur, max)
	if not cur or not max or max <= 0 then return "" end
	local pct = (cur / max) * 100
	return string.format("%s/%s (%.0f%%)", shortNumber(cur), shortNumber(max), pct)
end

local function formatPercent(cur, max)
	if not cur or not max or max <= 0 then return "" end
	return string.format("%.0f%%", (cur / max) * 100)
end

local function powerColor(unit)
	local powerType, powerToken = UnitPowerType(unit)
	local c = PowerBarColor[powerToken or powerType]
	if c then return c.r, c.g, c.b end
	return 0.2, 0.4, 1.0
end

local function unitNameColor(unit)
	-- Match Blizzard-style unit name coloring (class for players, reaction for NPCs).
	if UnitIsPlayer and UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		if c then return c.r, c.g, c.b end
	end
	if UnitReaction then
		local reaction = UnitReaction(unit, "player")
		local c = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
		if c then return c.r, c.g, c.b end
	end
	return 1, 1, 1
end

local function targetLevelColor(unit, lvl)
	-- Blizzard-like:
	-- - Friendly/neutral units: white (won't attack you)
	-- - Hostile/neutral units: level difficulty color (GetQuestDifficultyColor)
	if UnitReaction then
		local reaction = UnitReaction(unit, "player")
		-- Only friendly (5+) is forced white; neutral should use difficulty like enemies.
		if reaction and reaction >= 5 then
			return 1, 1, 1
		end
	end

	if type(lvl) == "number" and GetQuestDifficultyColor then
		local c = GetQuestDifficultyColor(lvl)
		if c then return c.r or 1, c.g or 1, c.b or 1 end
	end

	return 1, 1, 1
end

local function createBar(parent, height, labelLeft, labelRight)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	bar:SetHeight(height)

	local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
	border:SetAllPoints(bar)
	border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	border:SetBackdropBorderColor(0, 0, 0, 1)
	bar._huiBorder = border

	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	bg:SetAllPoints(bar)
	bg:SetVertexColor(0, 0, 0, 0.6)
	bar._huiBg = bg

	local baseFontSize = 12
	local left = U.Font(bar, baseFontSize, true)
	if left.SetFont then left:SetFont(STANDARD_TEXT_FONT, baseFontSize, "THICKOUTLINE") end
	left:SetPoint("LEFT", bar, "LEFT", 6, 0)
	left:SetJustifyH("LEFT")
	left:SetText(labelLeft or "")
	bar._huiLeft = left

	local center = U.Font(bar, baseFontSize, true)
	if center.SetFont then center:SetFont(STANDARD_TEXT_FONT, baseFontSize, "THICKOUTLINE") end
	center:SetPoint("CENTER", bar, "CENTER", 0, 0)
	center:SetJustifyH("CENTER")
	center:SetText("")
	bar._huiCenter = center

	local right = U.Font(bar, baseFontSize, true)
	if right.SetFont then right:SetFont(STANDARD_TEXT_FONT, baseFontSize, "THICKOUTLINE") end
	right:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
	right:SetJustifyH("RIGHT")
	right:SetText(labelRight or "")
	bar._huiRight = right

	return bar
end

local function applyBarFontSize(bar, size)
	if not bar then return end
	if bar._huiLeft and bar._huiLeft.SetFont then bar._huiLeft:SetFont(STANDARD_TEXT_FONT, size, "THICKOUTLINE") end
	if bar._huiCenter and bar._huiCenter.SetFont then bar._huiCenter:SetFont(STANDARD_TEXT_FONT, size, "THICKOUTLINE") end
	if bar._huiRight and bar._huiRight.SetFont then bar._huiRight:SetFont(STANDARD_TEXT_FONT, size, "THICKOUTLINE") end
end

local function createAuraButton(parent)
	local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
	b:SetSize(AURA_SIZE, AURA_SIZE)
	b:RegisterForClicks("AnyUp")

	local border = b:CreateTexture(nil, "BORDER")
	border:SetTexture("Interface\\Buttons\\WHITE8x8")
	border:SetVertexColor(0.6, 0.6, 0.6, 1)
	border:ClearAllPoints()
	border:SetPoint("TOPLEFT", b, "TOPLEFT", -AURA_BORDER_SIZE, AURA_BORDER_SIZE)
	border:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", AURA_BORDER_SIZE, -AURA_BORDER_SIZE)
	b._huiBorder = border

	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(b)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b._huiIcon = icon

	local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	cd:SetAllPoints(b)
	if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
	-- Common addon convention (OmniCC) to disable center countdown text.
	cd.noCooldownCount = true
	-- Swipe without the dark "shadow": keep swipe enabled but tint it.
	if cd.SetDrawSwipe then cd:SetDrawSwipe(true) end
	if cd.SetSwipeColor then cd:SetSwipeColor(1, 1, 1, 0.2) end
	if cd.SetDrawEdge then cd:SetDrawEdge(true) end
	if cd.SetDrawBling then cd:SetDrawBling(true) end
	b._huiCooldown = cd

	local count = U.Font(b, 11, true)
	if count.SetFont then count:SetFont(STANDARD_TEXT_FONT, 11, "THICKOUTLINE") end
	count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	count:SetJustifyH("RIGHT")
	count:SetText("")
	b._huiCount = count

	local time = U.Font(b, AURA_FONT_SIZE, true)
	if time.SetFont then time:SetFont(STANDARD_TEXT_FONT, AURA_FONT_SIZE, "THICKOUTLINE") end
	time:SetPoint("CENTER", b, "CENTER", 0, 0)
	time:SetJustifyH("CENTER")
	time:SetText("")
	b._huiTime = time

	b:Hide()
	return b
end

local function ensureAuraBar()
	if M._huiAuraBar then return end
	local f = CreateFrame("Frame", "HUI_AuraBar", UIParent)
	f:SetFrameStrata("MEDIUM")
	f:SetPoint("CENTER", UIParent, "CENTER", AURA_POS_X, AURA_POS_Y)
	f:SetSize(1, 1)
	f:Hide()
	M._huiAuraBar = f

	-- Weapon enchants (main/offhand) displayed as buffs in our aura bar.
	f._huiWeaponButtons = {
		createAuraButton(f),
		createAuraButton(f),
	}

	f._huiBuffButtons = {}
	f._huiDebuffButtons = {}
	for i = 1, AURA_MAX_BUFFS do
		f._huiBuffButtons[i] = createAuraButton(f)
	end
	for i = 1, AURA_MAX_DEBUFFS do
		f._huiDebuffButtons[i] = createAuraButton(f)
	end

	f._huiTimeAccumulator = 0
	f:SetScript("OnUpdate", function(self, elapsed)
		self._huiTimeAccumulator = (self._huiTimeAccumulator or 0) + (elapsed or 0)
		if self._huiTimeAccumulator < 0.2 then return end
		self._huiTimeAccumulator = 0

		local now = GetTime()
		local function updateButtonTime(btn)
			if not btn or not btn:IsShown() then return end
			local exp = btn._huiExpiration
			local dur = btn._huiDuration
			if not exp or not dur or dur <= 0 or exp <= 0 then
				if btn._huiTime then btn._huiTime:SetText("") end
				return
			end
			local remain = exp - now
			if remain <= 0 then
				if btn._huiTime then btn._huiTime:SetText("") end
				return
			end
			if remain >= 60 then
				if btn._huiTime then btn._huiTime:SetText(string.format("%d", math.floor(remain / 60))) end
			else
				if btn._huiTime then btn._huiTime:SetText(string.format("%d", math.ceil(remain))) end
			end
		end

		for _, btn in ipairs(self._huiBuffButtons) do updateButtonTime(btn) end
		for _, btn in ipairs(self._huiDebuffButtons) do updateButtonTime(btn) end
		if self._huiWeaponButtons then
			for _, btn in ipairs(self._huiWeaponButtons) do updateButtonTime(btn) end
		end
	end)
end

local function hideBlizzardWeaponEnchants()
	-- Blizzard displays weapon buffs via TemporaryEnchantFrame.
	local f = _G.TemporaryEnchantFrame
	if f and f.Hide then
		if f.UnregisterAllEvents then f:UnregisterAllEvents() end
		f:Hide()
		if f.SetScript then f:SetScript("OnShow", function(self) self:Hide() end) end
	end
	for i = 1, 2 do
		local b = _G["TemporaryEnchantFrame" .. i]
		if b and b.Hide then
			if b.UnregisterAllEvents then b:UnregisterAllEvents() end
			b:Hide()
			if b.SetScript then b:SetScript("OnShow", function(self) self:Hide() end) end
		end
	end
end

local function createTargetAuraButton(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(TARGET_AURA_SIZE, TARGET_AURA_SIZE)
	b:RegisterForClicks("AnyUp")

	local border = b:CreateTexture(nil, "BORDER")
	border:SetTexture("Interface\\Buttons\\WHITE8x8")
	border:SetVertexColor(0, 0, 0, 1)
	border:SetPoint("TOPLEFT", b, "TOPLEFT", -TARGET_AURA_BORDER_SIZE, TARGET_AURA_BORDER_SIZE)
	border:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", TARGET_AURA_BORDER_SIZE, -TARGET_AURA_BORDER_SIZE)
	b._huiBorder = border

	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(b)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b._huiIcon = icon

	local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	cd:SetAllPoints(b)
	if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
	cd.noCooldownCount = true
	if cd.SetDrawSwipe then cd:SetDrawSwipe(true) end
	if cd.SetSwipeColor then cd:SetSwipeColor(1, 1, 1, 0.35) end
	if cd.SetDrawEdge then cd:SetDrawEdge(false) end
	if cd.SetDrawBling then cd:SetDrawBling(false) end
	b._huiCooldown = cd

	local count = U.Font(b, 11, true)
	if count.SetFont then count:SetFont(STANDARD_TEXT_FONT, 11, "THICKOUTLINE") end
	count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	count:SetJustifyH("RIGHT")
	count:SetText("")
	b._huiCount = count

	local time = U.Font(b, TARGET_AURA_FONT_SIZE, true)
	if time.SetFont then time:SetFont(STANDARD_TEXT_FONT, TARGET_AURA_FONT_SIZE, "THICKOUTLINE") end
	time:SetPoint("CENTER", b, "CENTER", 0, 0)
	time:SetJustifyH("CENTER")
	time:SetText("")
	b._huiTime = time

	b:Hide()
	return b
end

local function ensureTargetAuraBar()
	if M._huiTargetAuraBar then return end
	local f = CreateFrame("Frame", "HUI_TargetAuraBar", UIParent)
	f:SetFrameStrata("MEDIUM")
	f:SetSize(1, 1)
	f:Hide()
	M._huiTargetAuraBar = f

	f._huiDebuffButtons = {}
	f._huiBuffButtons = {}
	for i = 1, TARGET_AURA_MAX_DEBUFFS do
		f._huiDebuffButtons[i] = createTargetAuraButton(f)
	end
	for i = 1, TARGET_AURA_MAX_BUFFS do
		f._huiBuffButtons[i] = createTargetAuraButton(f)
	end

	f._huiTimeAccumulator = 0
	f:SetScript("OnUpdate", function(self, elapsed)
		self._huiTimeAccumulator = (self._huiTimeAccumulator or 0) + (elapsed or 0)
		if self._huiTimeAccumulator < 0.2 then return end
		self._huiTimeAccumulator = 0

		local now = GetTime()
		local function updateButtonTime(btn)
			if not btn or not btn:IsShown() then return end
			local exp = btn._huiExpiration
			local dur = btn._huiDuration
			if not exp or not dur or dur <= 0 or exp <= 0 then
				if btn._huiTime then btn._huiTime:SetText("") end
				return
			end
			local remain = exp - now
			if remain <= 0 then
				if btn._huiTime then btn._huiTime:SetText("") end
				return
			end
			if remain >= 60 then
				if btn._huiTime then btn._huiTime:SetText(string.format("%d", math.floor(remain / 60))) end
			else
				if btn._huiTime then btn._huiTime:SetText(string.format("%d", math.ceil(remain))) end
			end
		end

		for _, btn in ipairs(self._huiDebuffButtons) do updateButtonTime(btn) end
		for _, btn in ipairs(self._huiBuffButtons) do updateButtonTime(btn) end
	end)
end

local function addLevelBadge(bar)
	local badge = CreateFrame("Frame", nil, bar)
	badge:SetSize(LEVEL_BADGE_W, LEVEL_BADGE_H)
	badge:SetPoint("LEFT", bar, "LEFT", LEVEL_BADGE_X, LEVEL_BADGE_Y)
	badge:SetFrameLevel((bar:GetFrameLevel() or 0) + 5)

	local bg = badge:CreateTexture(nil, "BACKGROUND")
	-- WeakAuras often shows atlas names; prefer SetAtlas over guessing file paths.
	if bg.SetAtlas then
		bg:SetAtlas("services-ring-countcircle", true)
	else
		bg:SetTexture("Interface\\Buttons\\WHITE8x8")
		bg:SetVertexColor(0, 0, 0, 0.35)
	end
	bg:ClearAllPoints()
	bg:SetPoint("CENTER", badge, "CENTER", LEVEL_BG_X, LEVEL_BG_Y)
	bg:SetSize(LEVEL_BG_W, LEVEL_BG_H)

	local border = badge:CreateTexture(nil, "BORDER")
	if border.SetAtlas then
		border:SetAtlas("Artifacts-PerkRing-GoldMedal", true)
	else
		border:SetTexture("Interface\\Buttons\\WHITE8x8")
		border:SetVertexColor(1, 0.82, 0, 1)
	end
	border:ClearAllPoints()
	border:SetPoint("CENTER", badge, "CENTER", LEVEL_FRAME_X, LEVEL_FRAME_Y)
	border:SetSize(LEVEL_FRAME_W, LEVEL_FRAME_H)
	-- Horizontal mirror.
	if border.SetTexCoord then
		border:SetTexCoord(1, 0, 0, 1)
	end

	local text = U.Font(badge, LEVEL_FONT_SIZE, true)
	if text.SetFont then text:SetFont(STANDARD_TEXT_FONT, LEVEL_FONT_SIZE, "THICKOUTLINE") end
	text:SetPoint("CENTER", badge, "CENTER", 0, 0)
	text:SetJustifyH("CENTER")
	text:SetText("")

	bar._huiLevelBadge = badge
	bar._huiLevelText = text
	bar._huiLevelBorder = border
	return badge
end

local function addPvPBadge(bar)
	local badge = CreateFrame("Frame", nil, bar)
	badge:SetSize(PVP_BADGE_W, PVP_BADGE_H)
	badge:SetFrameLevel((bar:GetFrameLevel() or 0) + 6)
	badge:Hide()

	local icon = badge:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(badge)
	badge._huiIcon = icon

	local timerText = U.Font(badge, PVP_TIMER_FONT_SIZE, true)
	if timerText.SetFont then timerText:SetFont(STANDARD_TEXT_FONT, PVP_TIMER_FONT_SIZE, "THICKOUTLINE") end
	timerText:SetPoint("BOTTOM", badge, "TOP", PVP_TIMER_OFFSET_X, PVP_TIMER_OFFSET_Y)
	timerText:SetJustifyH("CENTER")
	if timerText.SetTextColor then timerText:SetTextColor(PVP_TIMER_COLOR_R, PVP_TIMER_COLOR_G, PVP_TIMER_COLOR_B, 1) end
	timerText:SetText("")
	timerText:Hide()
	badge._huiTimerText = timerText
	badge._huiTimerLastSec = nil

	if bar._huiLevelBadge then
		badge:SetPoint("RIGHT", bar._huiLevelBadge, "LEFT", -PVP_BADGE_GAP, 0)
	else
		badge:SetPoint("LEFT", bar, "LEFT", 2, 0)
	end

	bar._huiPvPBadge = badge
	return badge
end

local function updatePvPBadge(bar, unit)
	if not bar or not bar._huiPvPBadge then return end
	if not unit or not UnitExists or not UnitExists(unit) then
		bar._huiPvPBadge:Hide()
		if bar._huiPvPBadge._huiTimerText then bar._huiPvPBadge._huiTimerText:Hide() end
		return
	end

	local isPvp = (UnitIsPVP and UnitIsPVP(unit)) and true or false
	local isFfa = (UnitIsPVPFreeForAll and UnitIsPVPFreeForAll(unit)) and true or false
	if not isPvp and not isFfa then
		bar._huiPvPBadge:Hide()
		if bar._huiPvPBadge._huiTimerText then bar._huiPvPBadge._huiTimerText:Hide() end
		return
	end

	local icon = bar._huiPvPBadge._huiIcon
	if icon then
		if isFfa then
			icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA")
		else
			local faction = UnitFactionGroup and UnitFactionGroup(unit) or nil
			if faction == "Alliance" then
				icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
			elseif faction == "Horde" then
				icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")
			else
				icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA")
			end
		end
	end

	bar._huiPvPBadge:Show()
	if bar._huiPvPBadge._huiTimerText then
		bar._huiPvPBadge._huiTimerLastSec = nil
		bar._huiPvPBadge._huiTimerLastMs = nil
		bar._huiPvPBadge._huiTimerRunning = nil
		bar._huiPvPBadge._huiTimerText:Hide()
	end
end

local function isAutoAttacking()
	if not IsCurrentSpell then return false end
	-- 6603 is "Auto Attack"
	return IsCurrentSpell(6603) and true or false
end

local function isAutoRepeating()
	if not IsAutoRepeatSpell then return false end
	return IsAutoRepeatSpell() and true or false
end

local function ensureFrames()
	if M._huiPlayer then return end

	-- Use a secure unit button so clicks behave like the Blizzard unitframe:
	-- Left click targets, right click opens the unit dropdown.
	local holder = CreateFrame("Button", "HUI_PlayerUnitFrame", UIParent, "SecureUnitButtonTemplate")
	holder:SetFrameStrata("LOW")
	holder:SetSize(PLAYER_W, HEALTH_H + GAP + POWER_H + GAP + CAST_H + GAP + PET_HEALTH_H + GAP + PET_POWER_H)
	holder:EnableMouse(true)
	holder:RegisterForClicks("AnyUp")
	holder:SetAttribute("unit", "player")
	holder:SetAttribute("*type1", "target")
	holder:SetAttribute("*type2", "togglemenu")
	if RegisterUnitWatch then RegisterUnitWatch(holder) end
	holder:Hide()
	M._huiPlayer = holder

	local health = createBar(holder, 28)
	health:SetPoint("TOP", holder, "TOP", 0, 0)
	addLevelBadge(health)
	addPvPBadge(health)
	M._huiPlayerHealth = health
	applyBarFontSize(health, 12 + HEALTH_TEXT_SIZE_DELTA)

	local power = createBar(holder, 18)
	power:SetPoint("TOP", health, "BOTTOM", 0, -GAP)
	M._huiPlayerPower = power

	local castSlot = CreateFrame("Frame", nil, holder)
	castSlot:SetPoint("TOP", power, "BOTTOM", 0, -GAP)
	castSlot:SetSize(PLAYER_W, CAST_H)
	M._huiPlayerCastSlot = castSlot

	local cast = createBar(holder, 22)
	cast:SetParent(castSlot)
	cast:SetAllPoints(castSlot)
	cast:Hide()
	M._huiPlayerCast = cast

	local swingMH = createBar(holder, 11, "Mainhand", "")
	swingMH:SetParent(castSlot)
	swingMH:SetPoint("TOPLEFT", castSlot, "TOPLEFT", 0, 0)
	swingMH:SetPoint("TOPRIGHT", castSlot, "TOPRIGHT", 0, 0)
	swingMH:Hide()
	M._huiPlayerSwingMH = swingMH

	local swingOH = createBar(holder, 11, "Offhand", "")
	swingOH:SetParent(castSlot)
	swingOH:SetPoint("BOTTOMLEFT", castSlot, "BOTTOMLEFT", 0, 0)
	swingOH:SetPoint("BOTTOMRIGHT", castSlot, "BOTTOMRIGHT", 0, 0)
	swingOH:Hide()
	M._huiPlayerSwingOH = swingOH

	local wand = createBar(holder, 22, "Wand", "")
	wand:SetParent(castSlot)
	wand:SetAllPoints(castSlot)
	wand:Hide()
	M._huiPlayerWand = wand

	-- Pet bars: separate secure unit button so clicks target the pet.
	local petButton = CreateFrame("Button", nil, holder, "SecureUnitButtonTemplate")
	petButton:EnableMouse(true)
	petButton:RegisterForClicks("AnyUp")
	petButton:SetAttribute("unit", "pet")
	petButton:SetAttribute("*type1", "target")
	petButton:SetAttribute("*type2", "togglemenu")
	if RegisterUnitWatch then RegisterUnitWatch(petButton) end
	petButton:SetPoint("TOP", castSlot, "BOTTOM", 0, -GAP)
	petButton:SetSize(PLAYER_W, PET_HEALTH_H + GAP + PET_POWER_H)
	petButton:Hide()
	M._huiPetButton = petButton

	local petHealth = createBar(petButton, 18)
	petHealth:SetPoint("TOP", petButton, "TOP", 0, 0)
	petHealth:Hide()
	M._huiPetHealth = petHealth

	local petPower = createBar(petButton, 14)
	petPower:SetPoint("TOP", petHealth, "BOTTOM", 0, -GAP)
	petPower:Hide()
	M._huiPetPower = petPower
	applyBarFontSize(petPower, 12 + PET_POWER_TEXT_SIZE_DELTA)

	-- Event driver
	local ev = CreateFrame("Frame")
	M._huiEventFrame = ev

	-- Target frame (secure unit button)
	local target = CreateFrame("Button", "HUI_TargetUnitFrame", UIParent, "SecureUnitButtonTemplate")
	target:SetFrameStrata("LOW")
	target:SetSize(TARGET_W, TARGET_NAME_H + TARGET_GAP + TARGET_HEALTH_H + TARGET_GAP + TARGET_POWER_H + TARGET_GAP + TARGET_CAST_H)
	target:EnableMouse(true)
	target:RegisterForClicks("AnyUp")
	target:SetAttribute("unit", "target")
	target:SetAttribute("*type1", "target")
	target:SetAttribute("*type2", "togglemenu")
	if RegisterUnitWatch then RegisterUnitWatch(target) end
	target:Hide()
	M._huiTarget = target

	local modelFrame = CreateFrame("Button", nil, UIParent, "BackdropTemplate,SecureUnitButtonTemplate")
	modelFrame:SetFrameStrata("LOW")
	modelFrame:SetSize(TARGET_MODEL_W, TARGET_MODEL_H)
	modelFrame:SetPoint("RIGHT", target, "LEFT", -TARGET_MODEL_GAP, 0)
	modelFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	modelFrame:SetBackdropColor(0, 0, 0, 0.35)
	modelFrame:SetBackdropBorderColor(0, 0, 0, 1)
	modelFrame:EnableMouse(true)
	modelFrame:RegisterForClicks("AnyUp")
	modelFrame:SetAttribute("unit", "target")
	modelFrame:SetAttribute("*type1", "target")
	modelFrame:SetAttribute("*type2", "togglemenu")
	if RegisterUnitWatch then RegisterUnitWatch(modelFrame) end
	modelFrame:Hide()
	M._huiTargetModelFrame = modelFrame

	local model = CreateFrame("PlayerModel", nil, modelFrame)
	model:SetAllPoints(modelFrame)
	model:EnableMouse(false)
	model:Hide()
	M._huiTargetModel = model

	local raidMark = modelFrame:CreateTexture(nil, "OVERLAY")
	raidMark:SetSize(TARGET_RAIDMARK_SIZE, TARGET_RAIDMARK_SIZE)
	raidMark:SetPoint("BOTTOM", modelFrame, "TOP", 0, 2)
	raidMark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	raidMark:Hide()
	M._huiTargetRaidMark = raidMark

		local name = U.Font(target, TARGET_NAME_FONT_SIZE, true)
		if name.SetFont then name:SetFont(STANDARD_TEXT_FONT, TARGET_NAME_FONT_SIZE, "THICKOUTLINE") end
		name:SetPoint("TOP", target, "TOP", 0, 0)
		name:SetJustifyH("CENTER")
		name:SetText("")
		M._huiTargetName = name

	local health = createBar(target, TARGET_HEALTH_H)
	health:SetPoint("TOP", name, "BOTTOM", 0, -(TARGET_GAP + TARGET_NAME_GAP))
	addLevelBadge(health)
	addPvPBadge(health)
	M._huiTargetHealth = health
	applyBarFontSize(health, 12 + HEALTH_TEXT_SIZE_DELTA)

	local power = createBar(target, TARGET_POWER_H)
	power:SetPoint("TOP", health, "BOTTOM", 0, -TARGET_GAP)
	M._huiTargetPower = power

	local castSlot = CreateFrame("Frame", nil, target)
	castSlot:SetPoint("TOP", power, "BOTTOM", 0, -TARGET_GAP)
	castSlot:SetSize(TARGET_W, TARGET_CAST_H)
	M._huiTargetCastSlot = castSlot

	local cast = createBar(target, TARGET_CAST_H)
	cast:SetParent(castSlot)
	cast:SetAllPoints(castSlot)
	cast:Hide()
	M._huiTargetCast = cast

	-- Combo points (Classic: 5) centered below target frame, growing outwards.
	local cpHolder = CreateFrame("Frame", nil, target)
	cpHolder:SetSize(1, 1)
	cpHolder:SetPoint("TOP", target, "BOTTOM", 0, TARGET_COMBO_OFFSET_Y)
	cpHolder:Hide()
	M._huiTargetCombo = cpHolder

	local CP_COUNT = 5
	local CP_SIZE = 18
	local CP_GAP = 2
	local CP_SHOW_ORDER = { 3, 2, 4, 1, 5 } -- grow from center outward
	cpHolder._points = {}
	cpHolder._showOrder = CP_SHOW_ORDER
	for i = 1, CP_COUNT do
		local tex = cpHolder:CreateTexture(nil, "OVERLAY")
		if tex.SetAtlas then
			tex:SetAtlas("ClassOverlay-ComboPoint", true)
		end
		tex:SetSize(CP_SIZE, CP_SIZE)
		local offset = (i - (CP_COUNT + 1) / 2) * (CP_SIZE + CP_GAP)
		tex:SetPoint("CENTER", cpHolder, "CENTER", offset, 0)
		tex:Hide()
		cpHolder._points[i] = tex
	end
	cpHolder:SetSize(CP_COUNT * CP_SIZE + (CP_COUNT - 1) * CP_GAP, CP_SIZE)

	-- TargetTarget: vertical bars + portrait to the right of target
	local totHolder = CreateFrame("Button", "HUI_TargetTargetUnitFrame", UIParent, "SecureUnitButtonTemplate")
	totHolder:SetFrameStrata("LOW")
	totHolder:EnableMouse(true)
	totHolder:RegisterForClicks("AnyUp")
	totHolder:SetAttribute("unit", "targettarget")
	totHolder:SetAttribute("*type1", "target")
		totHolder:SetAttribute("*type2", "togglemenu")
		if RegisterUnitWatch then RegisterUnitWatch(totHolder) end
		totHolder:Hide()
		M._huiToT = totHolder

		local totName = U.Font(totHolder, TOT_NAME_FONT_SIZE, true)
		if totName.SetFont then totName:SetFont(STANDARD_TEXT_FONT, TOT_NAME_FONT_SIZE, "THICKOUTLINE") end
		totName:SetPoint("BOTTOM", totHolder, "TOP", 0, TOT_NAME_GAP)
		totName:SetJustifyH("CENTER")
		totName:SetText("")
		M._huiToTName = totName

	local totHealth = CreateFrame("StatusBar", nil, totHolder)
	totHealth:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	totHealth:SetOrientation("VERTICAL")
	totHealth:SetMinMaxValues(0, 1)
	totHealth:SetValue(0)
	totHealth:SetSize(TOT_BAR_W, TOT_HEALTH_H)
	totHealth:SetStatusBarColor(0, 1, 0)
	local totHealthBg = totHealth:CreateTexture(nil, "BACKGROUND")
	totHealthBg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	totHealthBg:SetAllPoints(totHealth)
	totHealthBg:SetVertexColor(0, 0, 0, 0.6)
	local totHealthBorder = CreateFrame("Frame", nil, totHealth, "BackdropTemplate")
	totHealthBorder:SetAllPoints(totHealth)
	totHealthBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	totHealthBorder:SetBackdropBorderColor(0, 0, 0, 1)
	M._huiToTHealth = totHealth

	local totPower = CreateFrame("StatusBar", nil, totHolder)
	totPower:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	totPower:SetOrientation("VERTICAL")
	totPower:SetMinMaxValues(0, 1)
	totPower:SetValue(0)
	totPower:SetSize(TOT_BAR_W, TOT_POWER_H)
	totPower:SetStatusBarColor(0.2, 0.4, 1.0)
	local totPowerBg = totPower:CreateTexture(nil, "BACKGROUND")
	totPowerBg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	totPowerBg:SetAllPoints(totPower)
	totPowerBg:SetVertexColor(0, 0, 0, 0.6)
	local totPowerBorder = CreateFrame("Frame", nil, totPower, "BackdropTemplate")
	totPowerBorder:SetAllPoints(totPower)
	totPowerBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	totPowerBorder:SetBackdropBorderColor(0, 0, 0, 1)
	M._huiToTPower = totPower

	local totModelFrame = CreateFrame("Button", nil, UIParent, "BackdropTemplate,SecureUnitButtonTemplate")
	totModelFrame:SetFrameStrata("LOW")
	totModelFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	totModelFrame:SetBackdropColor(0, 0, 0, 0.35)
	totModelFrame:SetBackdropBorderColor(0, 0, 0, 1)
	totModelFrame:EnableMouse(true)
	totModelFrame:RegisterForClicks("AnyUp")
	totModelFrame:SetAttribute("unit", "targettarget")
	totModelFrame:SetAttribute("*type1", "target")
	totModelFrame:SetAttribute("*type2", "togglemenu")
	if RegisterUnitWatch then RegisterUnitWatch(totModelFrame) end
	totModelFrame:Hide()
	M._huiToTModelFrame = totModelFrame

	local totModel = CreateFrame("PlayerModel", nil, totModelFrame)
	totModel:SetAllPoints(totModelFrame)
	totModel:EnableMouse(false)
	totModel:Hide()
	M._huiToTModel = totModel
end

local function updateLayout()
	local holder = M._huiPlayer
	if not holder then return end

	holder:SetSize(PLAYER_W, HEALTH_H + GAP + POWER_H + GAP + CAST_H + GAP + PET_HEALTH_H + GAP + PET_POWER_H)
	local health = M._huiPlayerHealth
	local power = M._huiPlayerPower
	local castSlot = M._huiPlayerCastSlot
	local cast = M._huiPlayerCast
	local swingMH = M._huiPlayerSwingMH
	local swingOH = M._huiPlayerSwingOH
	local wand = M._huiPlayerWand
	local petButton = M._huiPetButton
	local petHealth = M._huiPetHealth
	local petPower = M._huiPetPower

	health:SetWidth(PLAYER_W)
	health:SetHeight(HEALTH_H)
	health:ClearAllPoints()
	health:SetPoint("TOP", holder, "TOP", 0, 0)

	power:SetWidth(PLAYER_W)
	power:SetHeight(POWER_H)
	power:ClearAllPoints()
	power:SetPoint("TOP", health, "BOTTOM", 0, -GAP)

	castSlot:ClearAllPoints()
	castSlot:SetPoint("TOP", power, "BOTTOM", 0, -GAP)
	castSlot:SetSize(PLAYER_W, CAST_H)

	cast:SetAllPoints(castSlot)
	wand:SetAllPoints(castSlot)

	local half = math.max(1, math.floor(CAST_H / 2))
	swingMH:SetHeight(half)
	swingOH:SetHeight(half)

	petButton:ClearAllPoints()
	petButton:SetPoint("TOP", castSlot, "BOTTOM", 0, -GAP)
	petButton:SetSize(PLAYER_W, PET_HEALTH_H + GAP + PET_POWER_H)

	petHealth:SetWidth(PLAYER_W)
	petHealth:SetHeight(PET_HEALTH_H)
	petHealth:ClearAllPoints()
	petHealth:SetPoint("TOP", petButton, "TOP", 0, 0)

	petPower:SetWidth(PLAYER_W)
	petPower:SetHeight(PET_POWER_H)
	petPower:ClearAllPoints()
	petPower:SetPoint("TOP", petHealth, "BOTTOM", 0, -GAP)

	holder:ClearAllPoints()
	holder:SetPoint("CENTER", UIParent, "CENTER", PLAYER_X, PLAYER_Y)

	-- Target layout
	local target = M._huiTarget
		if target then
			target:SetSize(TARGET_W, TARGET_NAME_H + TARGET_GAP + TARGET_HEALTH_H + TARGET_GAP + TARGET_POWER_H + TARGET_GAP + TARGET_CAST_H)
			target:ClearAllPoints()
			target:SetPoint("CENTER", UIParent, "CENTER", TARGET_X, TARGET_Y)

			if M._huiTargetModelFrame then
				M._huiTargetModelFrame:ClearAllPoints()
				M._huiTargetModelFrame:SetPoint("RIGHT", target, "LEFT", -TARGET_MODEL_GAP, 0)
				M._huiTargetModelFrame:SetSize(TARGET_MODEL_W, TARGET_MODEL_H)
			end

		if M._huiTargetName then
			M._huiTargetName:ClearAllPoints()
			M._huiTargetName:SetPoint("TOP", target, "TOP", 0, 0)
		end
		if M._huiTargetHealth then
			M._huiTargetHealth:SetWidth(TARGET_W)
			M._huiTargetHealth:SetHeight(TARGET_HEALTH_H)
			M._huiTargetHealth:ClearAllPoints()
			M._huiTargetHealth:SetPoint("TOP", M._huiTargetName, "BOTTOM", 0, -(TARGET_GAP + TARGET_NAME_GAP))
		end
		if M._huiTargetPower then
			M._huiTargetPower:SetWidth(TARGET_W)
			M._huiTargetPower:SetHeight(TARGET_POWER_H)
			M._huiTargetPower:ClearAllPoints()
			M._huiTargetPower:SetPoint("TOP", M._huiTargetHealth, "BOTTOM", 0, -TARGET_GAP)
		end
		if M._huiTargetCastSlot then
			M._huiTargetCastSlot:ClearAllPoints()
			M._huiTargetCastSlot:SetPoint("TOP", M._huiTargetPower, "BOTTOM", 0, -TARGET_GAP)
			M._huiTargetCastSlot:SetSize(TARGET_W, TARGET_CAST_H)
		end
			if M._huiTargetCast then
				M._huiTargetCast:SetAllPoints(M._huiTargetCastSlot)
			end
			if M._huiTargetCombo then
				M._huiTargetCombo:ClearAllPoints()
				M._huiTargetCombo:SetPoint("TOP", target, "BOTTOM", 0, TARGET_COMBO_OFFSET_Y)
			end
		end

	-- TargetTarget layout anchored to the right of target
	if M._huiToT and M._huiToTHealth and M._huiToTPower and M._huiToTModelFrame then
		local anchor = M._huiTarget or UIParent
		M._huiToT:ClearAllPoints()
		M._huiToT:SetPoint("LEFT", anchor, "RIGHT", TOT_OFFSET_X, 0)
		M._huiToT:SetSize(TOT_BAR_W * 2 + TOT_BAR_GAP, math.max(TOT_HEALTH_H, TOT_POWER_H))

		if M._huiToTName then
			M._huiToTName:ClearAllPoints()
			M._huiToTName:SetPoint("BOTTOM", M._huiToT, "TOP", 0, TOT_NAME_GAP)
		end

		M._huiToTHealth:ClearAllPoints()
		M._huiToTHealth:SetPoint("BOTTOMLEFT", M._huiToT, "BOTTOMLEFT", 0, 0)
		M._huiToTHealth:SetSize(TOT_BAR_W, TOT_HEALTH_H)

		M._huiToTPower:ClearAllPoints()
		M._huiToTPower:SetPoint("BOTTOMLEFT", M._huiToTHealth, "BOTTOMRIGHT", TOT_BAR_GAP, 0)
		M._huiToTPower:SetSize(TOT_BAR_W, TOT_POWER_H)

		M._huiToTModelFrame:ClearAllPoints()
		M._huiToTModelFrame:SetPoint("LEFT", M._huiToT, "RIGHT", TOT_MODEL_GAP, 0)
		M._huiToTModelFrame:SetSize(TOT_MODEL_W, TOT_MODEL_H)
	end
end

local function updatePlayerBars()
	local health = M._huiPlayerHealth
	local power = M._huiPlayerPower
	if not health or not power then return end

	local lvl = UnitLevel("player") or ""
	if lvl < 0 then lvl = "??" end
	local maxLvl = getMaxPlayerLevel()

	local curH = UnitHealth("player")
	local maxH = UnitHealthMax("player")
	health:SetMinMaxValues(0, math.max(1, maxH or 1))
	health:SetValue(curH or 0)
	health:SetStatusBarColor(0, 1, 0)
	if health._huiLevelText then
		health._huiLevelText:SetText(tostring(lvl))
		health._huiLeft:SetText("")
	else
		health._huiLeft:SetText(tostring(lvl))
	end
	if health._huiLevelBorder then
		if isHardcore() then
			health._huiLevelBorder:Show()
			if type(lvl) == "number" and lvl >= maxLvl then
				if health._huiLevelBorder.SetDesaturated then health._huiLevelBorder:SetDesaturated(false) end
				local c = 1 - (LEVEL_FRAME_DESAT_AT_MAX or 0)
				health._huiLevelBorder:SetVertexColor(c, c, c, 1)
			else
				if health._huiLevelBorder.SetDesaturated then health._huiLevelBorder:SetDesaturated(true) end
				local c = 1 - (LEVEL_FRAME_DESAT_BELOW_MAX or 0.35)
				health._huiLevelBorder:SetVertexColor(c, c, c, 1)
			end
		else
			health._huiLevelBorder:Hide()
		end
	end
	
	updatePvPBadge(health, "player")
	health._huiCenter:SetText(shortNumber(curH))
	health._huiRight:SetText(formatPercent(curH, maxH))

	local curP = UnitPower("player")
	local maxP = UnitPowerMax("player")
	power:SetMinMaxValues(0, math.max(1, maxP or 1))
	power:SetValue(curP or 0)
	local pr, pg, pb = powerColor("player")
	power:SetStatusBarColor(pr, pg, pb)
	if maxP and maxP > 0 then
		power._huiCenter:SetText(shortNumber(curP))
		power._huiRight:SetText(formatPercent(curP, maxP))
	else
		power._huiCenter:SetText("")
		power._huiRight:SetText("")
	end
	power._huiLeft:SetText("")
end

local function updatePlayerPvPRunoutTimer()
	local health = M._huiPlayerHealth
	local badge = health and health._huiPvPBadge
	local timerText = badge and badge._huiTimerText
	if not badge or not timerText then return end
	if not badge.IsShown or not badge:IsShown() then
		badge._huiTimerLastSec = nil
		badge._huiTimerLastMs = nil
		badge._huiTimerRunning = nil
		timerText:Hide()
		return
	end

	if UnitIsPVP and not UnitIsPVP("player") then
		badge._huiTimerLastSec = nil
		badge._huiTimerLastMs = nil
		badge._huiTimerRunning = nil
		timerText:Hide()
		return
	end

	local ms = pvpTimerRemainingMs()
	if not ms or ms <= 0 then
		badge._huiTimerLastSec = nil
		badge._huiTimerLastMs = nil
		badge._huiTimerRunning = nil
		timerText:Hide()
		return
	end

	-- Only show during the last 5 minutes.
	if ms >= 300000 then
		badge._huiTimerLastSec = nil
		badge._huiTimerLastMs = ms
		badge._huiTimerRunning = nil
		timerText:Hide()
		return
	end

	-- Only show when we've observed the timer actually decreasing (some builds can return a stuck value).
	local lastMs = badge._huiTimerLastMs
	if lastMs then
		if ms > lastMs + 500 then
			-- Re-flagged / timer jumped up; wait to observe a decrease again.
			badge._huiTimerRunning = nil
		elseif ms < lastMs - 100 then
			badge._huiTimerRunning = true
		elseif badge._huiTimerRunning and ms > lastMs - 50 then
			badge._huiTimerRunning = nil
		end
	end
	badge._huiTimerLastMs = ms
	if not badge._huiTimerRunning then
		badge._huiTimerLastSec = nil
		timerText:Hide()
		return
	end

	local sec = math.floor((ms + 999) / 1000)
	if sec ~= badge._huiTimerLastSec then
		badge._huiTimerLastSec = sec
		local m = math.floor(sec / 60)
		local s = sec - (m * 60)
		timerText:SetText(string.format("%d:%02d", m, s))
	end
	timerText:Show()
end

local function updatePetBars()
	local petHealth = M._huiPetHealth
	local petPower = M._huiPetPower
	if not petHealth or not petPower then return end

	if not UnitExists("pet") then
		if M._huiPetButton then M._huiPetButton:Hide() end
		petHealth:Hide()
		petPower:Hide()
		return
	end

	if M._huiPetButton then M._huiPetButton:Show() end
	petHealth:Show()
	petPower:Show()

	local curH = UnitHealth("pet")
	local maxH = UnitHealthMax("pet")
	petHealth:SetMinMaxValues(0, math.max(1, maxH or 1))
	petHealth:SetValue(curH or 0)
	petHealth:SetStatusBarColor(0, 1, 0)
	petHealth._huiLeft:SetText(UnitName("pet") or "")
	petHealth._huiCenter:SetText(shortNumber(curH))
	petHealth._huiRight:SetText(formatPercent(curH, maxH))

	local curP = UnitPower("pet")
	local maxP = UnitPowerMax("pet")
	petPower:SetMinMaxValues(0, math.max(1, maxP or 1))
	petPower:SetValue(curP or 0)
	local pr, pg, pb = powerColor("pet")
	petPower:SetStatusBarColor(pr, pg, pb)
	if maxP and maxP > 0 then
		petPower._huiCenter:SetText(shortNumber(curP))
		petPower._huiRight:SetText(formatPercent(curP, maxP))
	else
		petPower._huiCenter:SetText("")
		petPower._huiRight:SetText("")
	end
	petPower._huiLeft:SetText("")
end

local function updateCastBar()
	local cast = M._huiPlayerCast
	if not cast then return end

	local name, _, _, startMS, endMS = UnitCastingInfo("player")
	local isChannel = false
	if not name then
		name, _, _, startMS, endMS = UnitChannelInfo("player")
		isChannel = name ~= nil
	end

	if not name or not startMS or not endMS then
		cast:Hide()
		return
	end

	local now = GetTime() * 1000
	local duration = math.max(1, endMS - startMS)
	local elapsed = now - startMS
	if isChannel then
		elapsed = endMS - now
	end

	local progress = U.Clamp(elapsed / duration, 0, 1)
	cast:SetMinMaxValues(0, 1)
	cast:SetValue(progress)
	cast:SetStatusBarColor(1, 0.7, 0.2)

	local remain = (endMS - now) / 1000
	if isChannel then
		remain = (now - startMS) / 1000
	end
	cast._huiLeft:SetText(name)
	cast._huiRight:SetText(string.format("%.1fs", math.max(0, remain)))
	cast:Show()
end

local function updateTargetBars()
	local f = M._huiTarget
	local name = M._huiTargetName
	local health = M._huiTargetHealth
	local power = M._huiTargetPower
	if not f or not name or not health or not power then return end

	if not UnitExists("target") then
		f:Hide()
		if M._huiTargetCombo then M._huiTargetCombo:Hide() end
		if M._huiTargetModel then M._huiTargetModel:Hide() end
		if M._huiTargetModelFrame then M._huiTargetModelFrame:Hide() end
		return
	end
	f:Show()
	if M._huiTargetModel then
		if M._huiTargetModelFrame then M._huiTargetModelFrame:Show() end
		M._huiTargetModel:Show()
		if M._huiTargetModel.SetUnit then
			M._huiTargetModel:SetUnit("target")
		end
		if M._huiTargetModel.SetPortraitZoom then
			M._huiTargetModel:SetPortraitZoom(TARGET_MODEL_PORTRAIT_ZOOM)
		end
		if M._huiTargetModel.SetCamDistanceScale then
			M._huiTargetModel:SetCamDistanceScale(TARGET_MODEL_CAM_DISTANCE)
		end
	end
	if M._huiTargetRaidMark then
		local idx = GetRaidTargetIndex and GetRaidTargetIndex("target") or nil
		if idx and idx >= 1 and idx <= 8 then
			if SetRaidTargetIconTexture then
				SetRaidTargetIconTexture(M._huiTargetRaidMark, idx)
			else
				-- Fallback: assume a single horizontal strip of 8 icons.
				local left = (idx - 1) / 8
				local right = idx / 8
				M._huiTargetRaidMark:SetTexCoord(left, right, 0, 1)
			end
			M._huiTargetRaidMark:Show()
		else
			M._huiTargetRaidMark:Hide()
		end
	end

	local tName = UnitName("target") or ""
	name:SetText(tName)

	local lvl = UnitLevel("target") or ""
	if lvl < 0 then lvl = "??" end

	local curH = UnitHealth("target")
	local maxH = UnitHealthMax("target")
	health:SetMinMaxValues(0, math.max(1, maxH or 1))
	health:SetValue(curH or 0)
	do
		local r, g, b = unitNameColor("target")
		-- Dim tapped (same spirit as Blizzard UI).
		if UnitIsTapDenied and UnitIsTapDenied("target") then
			r, g, b = 0.6, 0.6, 0.6
		end
		health:SetStatusBarColor(r, g, b)
	end
	if health._huiLevelText then
		health._huiLevelText:SetText(tostring(lvl))
		-- Match Blizzard-style coloring (class for players, difficulty for NPCs).
		if tostring(lvl) == "??" then
			health._huiLevelText:SetTextColor(1, 0.2, 0.2, 1)
		else
			local r, g, b = targetLevelColor("target", lvl)
			health._huiLevelText:SetTextColor(r, g, b, 1)
		end
		health._huiLeft:SetText("")
	else
		health._huiLeft:SetText(tostring(lvl))
	end
	health._huiCenter:SetText(shortNumber(curH))
	health._huiRight:SetText(formatPercent(curH, maxH))

	-- Level ring behavior for target:
	-- normal: none
	-- rare: desaturated
	-- elite/rareelite/worldboss: saturated
		if health._huiLevelBorder then
			local classif = UnitClassification and UnitClassification("target") or "normal"
			if classif == "normal" then
				health._huiLevelBorder:Hide()
		else
			health._huiLevelBorder:Show()
			if classif == "rare" then
				if health._huiLevelBorder.SetDesaturated then health._huiLevelBorder:SetDesaturated(true) end
				health._huiLevelBorder:SetVertexColor(0.75, 0.75, 0.75, 1)
			elseif classif == "rareelite" or classif == "elite" or classif == "worldboss" then
				if health._huiLevelBorder.SetDesaturated then health._huiLevelBorder:SetDesaturated(false) end
				health._huiLevelBorder:SetVertexColor(1, 1, 1, 1)
			else
				-- Fallback: treat unknown classifications as "normal"
				health._huiLevelBorder:Hide()
			end
			end
		end

		updatePvPBadge(health, "target")

		local curP = UnitPower("target")
		local maxP = UnitPowerMax("target")
		if not maxP or maxP <= 0 then
			power:Hide()
		else
			power:Show()
			power:SetMinMaxValues(0, math.max(1, maxP))
			power:SetValue(curP or 0)
			local pr, pg, pb = powerColor("target")
			power:SetStatusBarColor(pr, pg, pb)
			power._huiLeft:SetText("")
			power._huiCenter:SetText(shortNumber(curP))
			power._huiRight:SetText(formatPercent(curP, maxP))
		end

		-- Combo points (player -> target)
		if M._huiTargetCombo and M._huiTargetCombo._points then
			local cp = 0
			if GetComboPoints then
				cp = GetComboPoints("player", "target") or 0
			elseif UnitPower and Enum and Enum.PowerType and Enum.PowerType.ComboPoints then
				cp = UnitPower("player", Enum.PowerType.ComboPoints) or 0
			end
			cp = math.max(0, math.min(5, cp))

			if cp > 0 then
				M._huiTargetCombo:Show()
				for i = 1, 5 do
					local t = M._huiTargetCombo._points[i]
					if t then t:Hide() end
				end
				local order = M._huiTargetCombo._showOrder or { 1, 2, 3, 4, 5 }
				for i = 1, cp do
					local idx = order[i]
					local t = idx and M._huiTargetCombo._points[idx]
					if t then t:Show() end
				end
			else
				M._huiTargetCombo:Hide()
			end
		end
	end

local function updateTargetCastBar()
	local cast = M._huiTargetCast
	if not cast then return end
	if not UnitExists("target") then
		cast:Hide()
		return
	end

	local name, _, _, startMS, endMS = UnitCastingInfo("target")
	local isChannel = false
	if not name then
		name, _, _, startMS, endMS = UnitChannelInfo("target")
		isChannel = name ~= nil
	end
	if not name or not startMS or not endMS then
		cast:Hide()
		return
	end

	local now = GetTime() * 1000
	local duration = math.max(1, endMS - startMS)
	local elapsed = now - startMS
	if isChannel then elapsed = endMS - now end
	local progress = U.Clamp(elapsed / duration, 0, 1)
	cast:SetMinMaxValues(0, 1)
	cast:SetValue(progress)
	cast:SetStatusBarColor(1, 0.7, 0.2)

	local remain = (endMS - now) / 1000
	if isChannel then remain = (now - startMS) / 1000 end
	cast._huiLeft:SetText(name)
	cast._huiCenter:SetText("")
	cast._huiRight:SetText(string.format("%.1fs", math.max(0, remain)))
	cast:Show()
end

local function updateToTBars()
	local holder = M._huiToT
	local health = M._huiToTHealth
	local power = M._huiToTPower
	if not holder or not health or not power then return end

		if not UnitExists("targettarget") then
			holder:Hide()
			if M._huiToTName then M._huiToTName:SetText("") end
			if M._huiToTModel then M._huiToTModel:Hide() end
			if M._huiToTModelFrame then M._huiToTModelFrame:Hide() end
			return
		end

		holder:Show()
		if M._huiToTName then
			M._huiToTName:SetText(UnitName("targettarget") or "")
		end

	local curH = UnitHealth("targettarget")
	local maxH = UnitHealthMax("targettarget")
	health:SetMinMaxValues(0, math.max(1, maxH or 1))
	health:SetValue(curH or 0)
	do
		local r, g, b = unitNameColor("targettarget")
		if UnitIsTapDenied and UnitIsTapDenied("targettarget") then
			r, g, b = 0.6, 0.6, 0.6
		end
		health:SetStatusBarColor(r, g, b)
	end

	local curP = UnitPower("targettarget")
	local maxP = UnitPowerMax("targettarget")
	if not maxP or maxP <= 0 then
		power:Hide()
	else
		power:Show()
		power:SetMinMaxValues(0, math.max(1, maxP))
		power:SetValue(curP or 0)
		local pr, pg, pb = powerColor("targettarget")
		power:SetStatusBarColor(pr, pg, pb)
	end

	if M._huiToTModel and M._huiToTModelFrame then
		M._huiToTModelFrame:Show()
		M._huiToTModel:Show()
		if M._huiToTModel.SetUnit then M._huiToTModel:SetUnit("targettarget") end
		if M._huiToTModel.SetPortraitZoom then M._huiToTModel:SetPortraitZoom(TOT_MODEL_PORTRAIT_ZOOM) end
		if M._huiToTModel.SetCamDistanceScale then M._huiToTModel:SetCamDistanceScale(TOT_MODEL_CAM_DISTANCE) end
	end
end

local function updateSwingTimers()
	local mh = M._huiPlayerSwingMH
	local oh = M._huiPlayerSwingOH
	if not mh or not oh then return end

	if not M._huiSwing then M._huiSwing = {} end
	local st = M._huiSwing

	local mhSpeed, ohSpeed = UnitAttackSpeed("player")
	if not mhSpeed or mhSpeed <= 0 then
		mh:Hide()
		oh:Hide()
		return
	end

	local now = GetTime()

	if not isAutoAttacking() and not UnitAffectingCombat("player") then
		mh:Hide()
		oh:Hide()
		return
	end

	-- Only show after we have observed at least one real swing from the combat log.
	if not st.mhStart or not st.mhEnd then
		mh:Hide()
		oh:Hide()
		return
	end

	-- If we haven't seen a swing in a while (out of range, target dead, etc), hide.
	if st.lastSwing and (now - st.lastSwing) > (mhSpeed * 2.5) then
		st.mhStart, st.mhEnd, st.ohStart, st.ohEnd = nil, nil, nil, nil
		mh:Hide()
		oh:Hide()
		return
	end

	if st.mhEnd <= now then
		-- We missed the combat log reset; advance using weapon speed to avoid freezing.
		st.mhStart = st.mhEnd
		st.mhEnd = st.mhStart + mhSpeed
	end

	local mhP = U.Clamp((now - st.mhStart) / math.max(0.001, (st.mhEnd - st.mhStart)), 0, 1)
	mh:SetMinMaxValues(0, 1)
	mh:SetValue(mhP)
	mh:SetStatusBarColor(0.9, 0.9, 0.9)
	mh._huiLeft:SetText("Mainhand")
	mh._huiRight:SetText(string.format("%.1f", math.max(0, st.mhEnd - now)))
	mh:Show()

	if ohSpeed and ohSpeed > 0 then
		if not st.ohStart or not st.ohEnd then
			-- Offhand swings aren't distinguishable via SWING_* events; approximate with an offset.
			st.ohStart = st.mhStart + (ohSpeed / 2)
			st.ohEnd = st.ohStart + ohSpeed
		end
		if st.ohEnd <= now then
			st.ohStart = st.ohEnd
			st.ohEnd = st.ohStart + ohSpeed
		end
		local ohP = U.Clamp((now - st.ohStart) / math.max(0.001, (st.ohEnd - st.ohStart)), 0, 1)
		oh:SetMinMaxValues(0, 1)
		oh:SetValue(ohP)
		oh:SetStatusBarColor(0.7, 0.7, 0.7)
		oh._huiLeft:SetText("Offhand")
		oh._huiRight:SetText(string.format("%.1f", math.max(0, st.ohEnd - now)))
		oh:Show()
	else
		oh:Hide()
	end
end

local function updateWandTimer()
	local wand = M._huiPlayerWand
	if not wand then return end

	if not M._huiWand then M._huiWand = {} end
	local st = M._huiWand

	if not isAutoRepeating() then
		st.active = false
		wand:Hide()
		return
	end

	local speed = select(4, UnitRangedDamage("player"))
	if not speed or speed <= 0 then
		wand:Hide()
		return
	end

	local now = GetTime()
	if not st.active then
		st.active = true
		st.start = now
		st.next = now + speed
	end
	if st.next <= now then
		local overshoot = now - st.next
		st.start = now - overshoot
		st.next = st.start + speed
	end

	local p = U.Clamp((now - st.start) / math.max(0.001, (st.next - st.start)), 0, 1)
	wand:SetMinMaxValues(0, 1)
	wand:SetValue(p)
	wand:SetStatusBarColor(0.9, 0.9, 0.2)
	wand._huiLeft:SetText("Wand")
	wand._huiRight:SetText(string.format("%.1f", math.max(0, st.next - now)))
	wand:Show()
end

local function updateCastOrTimers()
	local cast = M._huiPlayerCast
	local mh = M._huiPlayerSwingMH
	local oh = M._huiPlayerSwingOH
	local wand = M._huiPlayerWand
	if not cast or not mh or not oh or not wand then return end

	-- Casting/channeling has priority.
	local name = UnitCastingInfo("player") or UnitChannelInfo("player")
	if name then
		mh:Hide()
		oh:Hide()
		wand:Hide()
		updateCastBar()
		return
	end

	-- Wand/auto-repeat replaces cast bar.
	if isAutoRepeating() then
		cast:Hide()
		mh:Hide()
		oh:Hide()
		updateWandTimer()
		return
	end

	-- Otherwise show swing timers.
	cast:Hide()
	wand:Hide()
	updateSwingTimers()
end

local function updateAuraBar()
	ensureAuraBar()
	local bar = M._huiAuraBar
	if not bar then return end

	hideBlizzardWeaponEnchants()

		-- Collect auras.
		local weaponBuffs = {}
		local myBuffs = {}
		local otherBuffs = {}
		local debuffs = {}

	local function addAura(list, filter, index, name, icon, count, duration, expirationTime, isStealable)
		list[#list + 1] = {
			filter = filter,
			index = index,
			name = name,
			icon = icon,
			count = count,
			duration = duration,
			expirationTime = expirationTime,
			isStealable = isStealable,
		}
	end

	for i = 1, 40 do
		local name, icon, count, debuffType, duration, expirationTime, caster, isStealable = UnitAura("player", i, "HELPFUL")
		if not name then break end
		if caster == "player" then
			addAura(myBuffs, "HELPFUL", i, name, icon, count, duration, expirationTime, isStealable)
		else
			addAura(otherBuffs, "HELPFUL", i, name, icon, count, duration, expirationTime, isStealable)
		end
	end

	for i = 1, 40 do
		local name, icon, count, debuffType, duration, expirationTime, caster, isStealable = UnitAura("player", i, "HARMFUL")
		if not name then break end
		addAura(debuffs, "HARMFUL", i, name, icon, count, duration, expirationTime, isStealable)
	end

		-- Weapon enchants (main/offhand) count as "my buffs" and should not show on Blizzard frames.
		do
			local hasMH, mhExpMS, mhCharges, mhEnchantID, hasOH, ohExpMS, ohCharges, ohEnchantID =
				false, 0, 0, 0, false, 0, 0, 0
			if GetWeaponEnchantInfo then
				hasMH, mhExpMS, mhCharges, mhEnchantID, hasOH, ohExpMS, ohCharges, ohEnchantID = GetWeaponEnchantInfo()
			end
			local now = GetTime()

			local function addWeapon(slotIndex, expMS, charges)
				local icon = GetInventoryItemTexture and GetInventoryItemTexture("player", slotIndex == 1 and 16 or 17)
				weaponBuffs[#weaponBuffs + 1] = {
					type = "weapon",
					slot = slotIndex, -- 1 = mainhand, 2 = offhand
					name = (slotIndex == 1) and "Main Hand" or "Off Hand",
					icon = icon,
				count = charges or 0,
				duration = (expMS or 0) / 1000,
				expirationTime = now + ((expMS or 0) / 1000),
			}
		end

		if hasMH and mhExpMS and mhExpMS > 0 then
			addWeapon(1, mhExpMS, mhCharges)
		end
			if hasOH and ohExpMS and ohExpMS > 0 then
				addWeapon(2, ohExpMS, ohCharges)
			end
		end

		-- Prepend weapon buffs so they show up as the left-most part of the buff row.
		if #weaponBuffs > 0 then
			local merged = {}
			for i = 1, #weaponBuffs do merged[#merged + 1] = weaponBuffs[i] end
			for i = 1, #myBuffs do merged[#merged + 1] = myBuffs[i] end
			myBuffs = merged
		end

	-- Layout: center -> left side buffs, right side debuffs. Order (left->right):
	-- my buffs, other buffs, (optional spacer), debuffs.
	local totalBuffs = #myBuffs + #otherBuffs
	local hasBuffs = totalBuffs > 0
	local hasDebuffs = #debuffs > 0
	local spacer = (hasBuffs and hasDebuffs) and AURA_SPACER or 0

	local buffsWidth = (totalBuffs > 0) and (totalBuffs * AURA_SIZE + (totalBuffs - 1) * AURA_GAP) or 0
	local debuffsWidth = (hasDebuffs) and (#debuffs * AURA_SIZE + (#debuffs - 1) * AURA_GAP) or 0
	local totalWidth = buffsWidth + spacer + debuffsWidth

	bar:SetSize(math.max(1, totalWidth), AURA_SIZE)
	bar:Show()

	-- Place icons by CENTER relative to the bar center so a single aura is truly centered.
	local x = -totalWidth / 2 + (AURA_SIZE / 2)

	local function applyButton(btn, aura, unit)
		btn:SetSize(AURA_SIZE, AURA_SIZE)
		btn._huiExpiration = aura.expirationTime
		btn._huiDuration = aura.duration
		btn._huiAuraIndex = aura.index
		btn._huiAuraFilter = aura.filter

		if btn._huiIcon then btn._huiIcon:SetTexture(aura.icon) end
		if btn._huiCount then
			if aura.count and aura.count > 1 then
				btn._huiCount:SetText(tostring(aura.count))
			else
				btn._huiCount:SetText("")
			end
		end
		if btn._huiCooldown and aura.duration and aura.duration > 0 and aura.expirationTime and aura.expirationTime > 0 then
			btn._huiCooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
		elseif btn._huiCooldown then
			btn._huiCooldown:Clear()
		end

		-- Weapon enchants are not real UnitAuras; handle tooltip/cancel separately.
		if aura.type == "weapon" then
			btn:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				local slot = (aura.slot == 1) and 16 or 17
				if GameTooltip.SetInventoryItem then
					GameTooltip:SetInventoryItem("player", slot)
				end
				GameTooltip:Show()
			end)
			btn:SetScript("OnLeave", function()
				if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
			end)
			btn:SetScript("OnClick", function(_, button)
				if button ~= "RightButton" then return end
				if CancelItemTempEnchantment then
					CancelItemTempEnchantment(aura.slot)
				end
			end)
			btn:EnableMouse(true)
		else
			-- Tooltip
			btn:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetUnitAura(unit, self._huiAuraIndex, self._huiAuraFilter)
				GameTooltip:Show()
			end)
			btn:SetScript("OnLeave", function()
				if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
			end)

			-- Cancel on RIGHT click for buffs (Blizzard-style).
			if aura.filter == "HELPFUL" then
				if InCombatLockdown and InCombatLockdown() then
					-- Do not change attributes in combat.
				else
					btn:SetAttribute("*type1", nil)
					btn:SetAttribute("*type2", "cancelaura")
					btn:SetAttribute("unit", unit)
					btn:SetAttribute("index", aura.index)
				end
				btn:EnableMouse(true)
			else
				-- Debuffs not cancelable.
				if InCombatLockdown and InCombatLockdown() then
					-- no-op
				else
					btn:SetAttribute("*type1", nil)
					btn:SetAttribute("*type2", nil)
					btn:SetAttribute("unit", nil)
					btn:SetAttribute("index", nil)
				end
				btn:EnableMouse(true)
			end
		end

		btn:Show()
	end

	-- Hide all first
	if bar._huiWeaponButtons then
		for _, btn in ipairs(bar._huiWeaponButtons) do btn:Hide() end
	end
	for _, btn in ipairs(bar._huiBuffButtons) do btn:Hide() end
	for _, btn in ipairs(bar._huiDebuffButtons) do btn:Hide() end

	local buffButtonIndex = 1
	local buffsPlaced = 0
	-- Weapon buttons take the first slots.
	local weaponPlaced = 0
	if bar._huiWeaponButtons then
		for _, aura in ipairs(myBuffs) do
			if aura.type ~= "weapon" then break end
			weaponPlaced = weaponPlaced + 1
			local btn = bar._huiWeaponButtons[weaponPlaced]
			if not btn then break end
			btn:SetPoint("CENTER", bar, "CENTER", x, 0)
			applyButton(btn, aura, "player")
			buffsPlaced = buffsPlaced + 1
			x = x + AURA_SIZE
			if buffsPlaced < totalBuffs then x = x + AURA_GAP end
		end
	end

	for _, aura in ipairs(myBuffs) do
		if aura.type == "weapon" then
			-- already handled above
		else
		local btn = bar._huiBuffButtons[buffButtonIndex]
		if not btn then break end
		btn:SetPoint("CENTER", bar, "CENTER", x, 0)
		applyButton(btn, aura, "player")
		buffsPlaced = buffsPlaced + 1
		x = x + AURA_SIZE
		if buffsPlaced < totalBuffs then x = x + AURA_GAP end
		buffButtonIndex = buffButtonIndex + 1
		end
	end
	for _, aura in ipairs(otherBuffs) do
		local btn = bar._huiBuffButtons[buffButtonIndex]
		if not btn then break end
		btn:SetPoint("CENTER", bar, "CENTER", x, 0)
		applyButton(btn, aura, "player")
		buffsPlaced = buffsPlaced + 1
		x = x + AURA_SIZE
		if buffsPlaced < totalBuffs then x = x + AURA_GAP end
		buffButtonIndex = buffButtonIndex + 1
	end

	if spacer > 0 then
		x = x + spacer
	end

	local debuffButtonIndex = 1
	for i, aura in ipairs(debuffs) do
		local btn = bar._huiDebuffButtons[debuffButtonIndex]
		if not btn then break end
		btn:SetPoint("CENTER", bar, "CENTER", x, 0)
		applyButton(btn, aura, "player")
		x = x + AURA_SIZE
		if i < #debuffs then x = x + AURA_GAP end
		debuffButtonIndex = debuffButtonIndex + 1
	end
end

local function updateTargetAuraBar()
	ensureTargetAuraBar()
	local bar = M._huiTargetAuraBar
	local targetFrame = M._huiTarget
	if not bar or not targetFrame then return end

	if not UnitExists("target") then
		bar:Hide()
		return
	end

	-- Anchor below target power bar (and above cast slot).
	if M._huiTargetCastSlot then
		bar:ClearAllPoints()
		bar:SetPoint("BOTTOM", M._huiTargetCastSlot, "TOP", TARGET_AURA_POS_X, 6 + TARGET_AURA_POS_Y)
	else
		bar:ClearAllPoints()
		bar:SetPoint("TOP", targetFrame, "BOTTOM", TARGET_AURA_POS_X, -6 + TARGET_AURA_POS_Y)
	end

	local myDebuffs = {}
	local otherDebuffs = {}
	local buffs = {}

	local function addAura(list, filter, index, name, icon, count, duration, expirationTime, caster)
		list[#list + 1] = {
			filter = filter,
			index = index,
			name = name,
			icon = icon,
			count = count,
			duration = duration,
			expirationTime = expirationTime,
			caster = caster,
		}
	end

	for i = 1, 40 do
		local name, icon, count, _, duration, expirationTime, caster = UnitAura("target", i, "HARMFUL")
		if not name then break end
		if caster == "player" then
			addAura(myDebuffs, "HARMFUL", i, name, icon, count, duration, expirationTime, caster)
		else
			addAura(otherDebuffs, "HARMFUL", i, name, icon, count, duration, expirationTime, caster)
		end
	end

	for i = 1, 40 do
		local name, icon, count, _, duration, expirationTime, caster = UnitAura("target", i, "HELPFUL")
		if not name then break end
		addAura(buffs, "HELPFUL", i, name, icon, count, duration, expirationTime, caster)
	end

	local totalDebuffs = #myDebuffs + #otherDebuffs
	local hasDebuffs = totalDebuffs > 0
	local hasBuffs = #buffs > 0
	local spacer = (hasDebuffs and hasBuffs) and TARGET_AURA_SPACER or 0

	local debuffsWidth = (totalDebuffs > 0) and (totalDebuffs * TARGET_AURA_SIZE + (totalDebuffs - 1) * TARGET_AURA_GAP) or 0
	local buffsWidth = (hasBuffs) and (#buffs * TARGET_AURA_SIZE + (#buffs - 1) * TARGET_AURA_GAP) or 0
	local totalWidth = debuffsWidth + spacer + buffsWidth

	bar:SetSize(math.max(1, totalWidth), TARGET_AURA_SIZE)
	bar:Show()

	for _, btn in ipairs(bar._huiDebuffButtons) do btn:Hide() end
	for _, btn in ipairs(bar._huiBuffButtons) do btn:Hide() end

	local x = -totalWidth / 2 + (TARGET_AURA_SIZE / 2)

	local function applyButton(btn, aura, unit)
		btn:SetSize(TARGET_AURA_SIZE, TARGET_AURA_SIZE)
		btn._huiExpiration = aura.expirationTime
		btn._huiDuration = aura.duration
		btn._huiAuraIndex = aura.index
		btn._huiAuraFilter = aura.filter
		if btn._huiIcon then btn._huiIcon:SetTexture(aura.icon) end
		if btn._huiCount then
			if aura.count and aura.count > 1 then btn._huiCount:SetText(tostring(aura.count)) else btn._huiCount:SetText("") end
		end
		if btn._huiCooldown and aura.duration and aura.duration > 0 and aura.expirationTime and aura.expirationTime > 0 then
			btn._huiCooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
		elseif btn._huiCooldown then
			btn._huiCooldown:Clear()
		end
		btn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetUnitAura(unit, self._huiAuraIndex, self._huiAuraFilter)
			GameTooltip:Show()
		end)
		btn:SetScript("OnLeave", function()
			if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
		end)
		btn:Show()
	end

	local debuffIndex = 1
	local placedDebuffs = 0
	for _, aura in ipairs(myDebuffs) do
		local btn = bar._huiDebuffButtons[debuffIndex]
		if not btn then break end
		btn:SetPoint("CENTER", bar, "CENTER", x, 0)
		applyButton(btn, aura, "target")
		debuffIndex = debuffIndex + 1
		placedDebuffs = placedDebuffs + 1
		x = x + TARGET_AURA_SIZE
		if placedDebuffs < totalDebuffs then x = x + TARGET_AURA_GAP end
	end
	for _, aura in ipairs(otherDebuffs) do
		local btn = bar._huiDebuffButtons[debuffIndex]
		if not btn then break end
		btn:SetPoint("CENTER", bar, "CENTER", x, 0)
		applyButton(btn, aura, "target")
		debuffIndex = debuffIndex + 1
		placedDebuffs = placedDebuffs + 1
		x = x + TARGET_AURA_SIZE
		if placedDebuffs < totalDebuffs then x = x + TARGET_AURA_GAP end
	end

	if spacer > 0 then x = x + spacer end

	for i, aura in ipairs(buffs) do
		local btn = bar._huiBuffButtons[i]
		if not btn then break end
		btn:SetPoint("CENTER", bar, "CENTER", x, 0)
		applyButton(btn, aura, "target")
		x = x + TARGET_AURA_SIZE
		if i < #buffs then x = x + TARGET_AURA_GAP end
	end
end

local function applyEnabled(db, enabled)
	ensureFrames()
	if not M._huiPlayer then return end

	if not enabled then
		M._huiPlayer:Hide()
		if M._huiTarget then M._huiTarget:Hide() end
		if M._huiTargetModel then M._huiTargetModel:Hide() end
		if M._huiTargetModelFrame then M._huiTargetModelFrame:Hide() end
		if M._huiToT then M._huiToT:Hide() end
		if M._huiToTModel then M._huiToTModel:Hide() end
		if M._huiToTModelFrame then M._huiToTModelFrame:Hide() end
		if M._huiTargetAuraBar then M._huiTargetAuraBar:Hide() end
		if M._huiAuraBar then M._huiAuraBar:Hide() end
		if M._huiEventFrame then
			M._huiEventFrame:SetScript("OnEvent", nil)
			M._huiEventFrame:SetScript("OnUpdate", nil)
			M._huiEventFrame:UnregisterAllEvents()
		end
		return
	end

	updateLayout()
	M._huiPlayer:Show()
	updatePlayerBars()
	updatePetBars()
	updateCastOrTimers()
	updateAuraBar()
	updateTargetBars()
	updateTargetCastBar()
	updateTargetAuraBar()
	updateToTBars()

		local ev = M._huiEventFrame
		ev:UnregisterAllEvents()
			ev:RegisterEvent("PLAYER_ENTERING_WORLD")
		ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		ev:RegisterEvent("ZONE_CHANGED")
		ev:RegisterEvent("ZONE_CHANGED_INDOORS")
		ev:RegisterEvent("PLAYER_FLAGS_CHANGED")
		ev:RegisterEvent("UNIT_FACTION")
		ev:RegisterEvent("START_AUTOREPEAT_SPELL")
		ev:RegisterEvent("STOP_AUTOREPEAT_SPELL")
		ev:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	ev:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", "player", "pet")
	ev:RegisterUnitEvent("UNIT_MAXHEALTH", "player", "pet")
		ev:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player", "pet")
	ev:RegisterUnitEvent("UNIT_MAXPOWER", "player", "pet")
	ev:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player", "pet")
	ev:RegisterUnitEvent("UNIT_FLAGS", "player", "target")
	ev:RegisterEvent("UNIT_PET")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
		ev:RegisterUnitEvent("UNIT_AURA", "player")
		ev:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
	ev:RegisterEvent("PLAYER_TARGET_CHANGED")
	ev:RegisterEvent("RAID_TARGET_UPDATE")
	ev:RegisterUnitEvent("UNIT_MODEL_CHANGED", "target")
	ev:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", "target")
	ev:RegisterUnitEvent("UNIT_MAXHEALTH", "target")
	ev:RegisterUnitEvent("UNIT_POWER_FREQUENT", "target")
	ev:RegisterUnitEvent("UNIT_MAXPOWER", "target")
	ev:RegisterUnitEvent("UNIT_DISPLAYPOWER", "target")
	ev:RegisterUnitEvent("UNIT_LEVEL", "target")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_START", "target")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "target")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "target")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "target")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "target")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "target")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "target")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "target")
	ev:RegisterUnitEvent("UNIT_AURA", "target")
	ev:RegisterEvent("UNIT_TARGET")
	ev:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", "targettarget")
	ev:RegisterUnitEvent("UNIT_MAXHEALTH", "targettarget")
	ev:RegisterUnitEvent("UNIT_POWER_FREQUENT", "targettarget")
	ev:RegisterUnitEvent("UNIT_MAXPOWER", "targettarget")
	ev:RegisterUnitEvent("UNIT_DISPLAYPOWER", "targettarget")
	ev:RegisterUnitEvent("UNIT_MODEL_CHANGED", "targettarget")

		ev:SetScript("OnEvent", function(_, event, unit)
		if event == "COMBAT_LOG_EVENT_UNFILTERED" then
			local _, subEvent, _, srcGUID = CombatLogGetCurrentEventInfo()
			if srcGUID == UnitGUID("player") and (subEvent == "SWING_DAMAGE" or subEvent == "SWING_MISSED") then
				if not M._huiSwing then M._huiSwing = {} end
				local st = M._huiSwing
				local now = GetTime()
				local mhSpeed = UnitAttackSpeed("player")
				if mhSpeed and mhSpeed > 0 then
					st.mhStart = now
					st.mhEnd = now + mhSpeed
					st.lastSwing = now
					-- Force offhand to re-seed after a real swing so it doesn't drift forever.
					st.ohStart, st.ohEnd = nil, nil
				end
			end
			return
		end
			if event == "UNIT_PET" then
				if unit == "player" then updatePetBars() end
				return
			end
			if event == "UNIT_INVENTORY_CHANGED" and unit == "player" then
				updateAuraBar()
				return
			end
			if event == "UNIT_POWER_FREQUENT" and unit == "player" then
				-- Combo points are player power but displayed on the target frame.
				updateTargetBars()
			end
			if unit == "player"
				or event == "PLAYER_ENTERING_WORLD"
				or event == "ZONE_CHANGED_NEW_AREA"
				or event == "ZONE_CHANGED"
				or event == "ZONE_CHANGED_INDOORS"
			then
				updatePlayerBars()
				updateCastOrTimers()
				updateAuraBar()
			end
			if event == "PLAYER_FLAGS_CHANGED" and (not unit or unit == "player") then
				updatePlayerBars()
			end
			if event == "UNIT_FLAGS" and unit == "player" then
				updatePlayerBars()
			end
			if event == "UNIT_FACTION" then
				if not unit or unit == "player" then updatePlayerBars() end
				if unit == "target" then updateTargetBars() end
			end
		if event == "PLAYER_TARGET_CHANGED" or unit == "target" then
			updateTargetBars()
			updateTargetCastBar()
			updateTargetAuraBar()
			updateToTBars()
		end
		if event == "UNIT_TARGET" and unit == "target" then
			updateToTBars()
		end
		if unit == "targettarget" then
			updateToTBars()
		end
	if event == "RAID_TARGET_UPDATE" then
		updateTargetBars()
	end
		if unit == "pet" or event == "PLAYER_ENTERING_WORLD" then
			updatePetBars()
		end
		if event == "START_AUTOREPEAT_SPELL" or event == "STOP_AUTOREPEAT_SPELL" then
			updateCastOrTimers()
		end
	end)
			ev._huiPvPPoll = nil
			ev:SetScript("OnUpdate", function(_, elapsed)
				updateCastOrTimers()
				updateTargetCastBar()
				ev._huiPvPPoll = (ev._huiPvPPoll or 0) + (elapsed or 0)
				if ev._huiPvPPoll >= 0.2 then
					ev._huiPvPPoll = 0
					updatePlayerPvPRunoutTimer()
				end
			end)
	end

function M:Apply(db)
	db = db or HUI:GetDB()

	-- Unit frames are protected; avoid combat lockdown issues.
	if InCombatLockdown and InCombatLockdown() then return end

	local useCustom = true

	-- Hide Blizzard when using custom.
	setShown(_G.PlayerFrame, not useCustom)
	setShown(_G.TargetFrame, not useCustom)
	setShown(_G.TargetFrameToT, not useCustom)
	setShown(_G.FocusFrame, not useCustom)
	forceHide(_G.TargetFrame)
	forceHide(_G.TargetFrameToT)
	hideBlizzardAurasAndCastbar()

	applyEnabled(db, useCustom)
end

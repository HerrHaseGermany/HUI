local _, HUI = ...

local M = { name = "nameplates" }
table.insert(HUI.modules, M)

local PLATE_W, PLATE_H = 250, 30
local COLOR_BORDER = { 0, 0, 0, 1 }
local RESOURCE_H = 5
local NAME_SIZE, SUB_SIZE = 18, 16
local MIN_NAME_SIZE, MIN_SUB_SIZE = 10, 10
local TEXT_MAX_W = PLATE_W - 120 -- leave room for level/hp
local LEVEL_BADGE_W, LEVEL_BADGE_H = 40, 40
local LEVEL_BG_W, LEVEL_BG_H = 40, 40
local LEVEL_FRAME_W, LEVEL_FRAME_H = 48, 48
local LEVEL_FONT_SIZE = 18
local PVP_BADGE_W, PVP_BADGE_H = 60, 60
local PVP_BADGE_GAP = 42
local QUEST_ICON_W, QUEST_ICON_H = 18, 18

local QUEST_ICON_AVAILABLE = "Interface\\GossipFrame\\AvailableQuestIcon"
local QUEST_ICON_ACTIVE = "Interface\\GossipFrame\\ActiveQuestIcon"
local RAIDMARK_SIZE = 36
local HP_FONT_SIZE = 18
local HP_FONT_MIN = 12
local HP_DIGITS_BASE = 3

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

local function powerColor(unit)
	local powerType, powerToken = UnitPowerType(unit)
	local c = PowerBarColor and PowerBarColor[powerToken or powerType]
	if c then return c.r, c.g, c.b end
	return 0.2, 0.4, 1.0
end

local function fitDigitsText(fs, text, baseDigits, baseSize, minSize)
	if not fs or not fs.SetFont then return end
	local s = tostring(text or "")
	local n = #s
	if n <= (baseDigits or 3) then
		fs:SetFont(STANDARD_TEXT_FONT, baseSize, "THICKOUTLINE")
		return
	end
	local scale = (baseDigits or 3) / n
	local size = math.floor((baseSize or 12) * scale + 0.5)
	if size < (minSize or 1) then size = minSize or 1 end
	fs:SetFont(STANDARD_TEXT_FONT, size, "THICKOUTLINE")
end

local function formatHPText(hp)
	hp = tonumber(hp) or 0
	if hp >= 1000000 then
		-- 7+ digits: show millions (XXM, XXXM, ...), rounded.
		local m = math.floor((hp + 500000) / 1000000)
		local ms = tostring(m)
		return ms .. "M", (#ms + 1)
	end
	if hp >= 10000 then
		-- 5-6 digits: show thousands (XXk, XXXk, ...), rounded.
		local k = math.floor((hp + 500) / 1000)
		local ks = tostring(k)
		return ks .. "k", (#ks + 1)
	end
	return tostring(hp), HP_DIGITS_BASE
end

local function getNPCTitle(unit)
	if not unit then return "" end
	local guid = UnitGUID and UnitGUID(unit)
	if not guid then return "" end
	M._titleCache = M._titleCache or {}
	local cached = M._titleCache[guid]
	if cached ~= nil then return cached end

	if not M._scanTip then
		local tip = CreateFrame("GameTooltip", "HUI_NameplateScanTooltip", UIParent, "GameTooltipTemplate")
		tip:SetOwner(UIParent, "ANCHOR_NONE")
		M._scanTip = tip
	end

	local tip = M._scanTip
	tip:ClearLines()
	tip:SetUnit(unit)
	local t = _G.HUI_NameplateScanTooltipTextLeft2 and _G.HUI_NameplateScanTooltipTextLeft2:GetText() or ""
	tip:ClearLines()
	if not t or t == "" then
		M._titleCache[guid] = ""
		return ""
	end

	-- Ignore "Level X" (or localized equivalents) for NPCs with no real title.
	do
		local lvl = UnitLevel and UnitLevel(unit) or nil
		if lvl and lvl > 0 then
			local low = string.lower(t)
			local n = tostring(lvl)
			if low:match("^level%s*" .. n .. "%s*$") or low:match("^stufe%s*" .. n .. "%s*$") then
				t = ""
			end
		end
	end

	M._titleCache[guid] = t
	return t
end

local function fitText(fs, text, maxW, baseSize, minSize)
	if not fs then return end
	-- Don't constrain width (it can clip); instead shrink font size until it fits.
	if fs.SetWidth then fs:SetWidth(0) end
	if fs.SetWordWrap then fs:SetWordWrap(false) end
	if fs.SetMaxLines then fs:SetMaxLines(0) end
	fs:SetText(text or "")
	if not fs.GetStringWidth then return end

	fs:SetFont(STANDARD_TEXT_FONT, baseSize, "THICKOUTLINE")
	local w = fs:GetStringWidth() or 0
	if w <= maxW then
		return
	end

	local size = baseSize
	while size > minSize do
		size = size - 1
		fs:SetFont(STANDARD_TEXT_FONT, size, "THICKOUTLINE")
		if (fs:GetStringWidth() or 0) <= maxW then break end
	end
end

local function fitTwoLine(nameFS, subFS, nameText, subText, maxW, nameBase, nameMin, subBase, subMin, maxH)
	if not nameFS or not subFS then return end
	if nameFS.SetWidth then nameFS:SetWidth(0) end
	if subFS.SetWidth then subFS:SetWidth(0) end
	if nameFS.SetWordWrap then nameFS:SetWordWrap(false) end
	if subFS.SetWordWrap then subFS:SetWordWrap(false) end
	if nameFS.SetMaxLines then nameFS:SetMaxLines(0) end
	if subFS.SetMaxLines then subFS:SetMaxLines(0) end

	nameFS:SetText(nameText or "")
	subFS:SetText(subText or "")

	local nameSize, subSize = nameBase, subBase
	local function apply()
		nameFS:SetFont(STANDARD_TEXT_FONT, nameSize, "THICKOUTLINE")
		subFS:SetFont(STANDARD_TEXT_FONT, subSize, "THICKOUTLINE")
	end

	apply()

	while true do
		local nameW = nameFS.GetStringWidth and (nameFS:GetStringWidth() or 0) or 0
		local subW = subFS.GetStringWidth and (subFS:GetStringWidth() or 0) or 0
		local nameH = nameFS.GetStringHeight and (nameFS:GetStringHeight() or 0) or 0
		local subH = subFS.GetStringHeight and (subFS:GetStringHeight() or 0) or 0
		local okW = (nameW <= maxW) and (subW <= maxW)
		local okH = (nameH + subH) <= maxH
		if okW and okH then break end

		local canName = nameSize > nameMin
		local canSub = subSize > subMin
		if not canName and not canSub then break end

		if canName and (not okW or not okH) then nameSize = nameSize - 1 end
		if canSub and (not okW or not okH) then subSize = subSize - 1 end
		apply()
	end
end

local function updatePvPBadge(uf, unit)
	local badge = uf and uf._HUIPvPBadge
	if not badge then return end
	if not unit or not UnitExists or not UnitExists(unit) then
		badge:Hide()
		return
	end

	if not UnitIsPVP or not UnitIsPVP(unit) then
		badge:Hide()
		return
	end

	local icon = badge._huiIcon
	if icon then
		if UnitIsPVPFreeForAll and UnitIsPVPFreeForAll(unit) then
			icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA")
		elseif UnitFactionGroup then
			local faction = UnitFactionGroup(unit)
			if faction == "Horde" then
				icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")
			elseif faction == "Alliance" then
				icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
			else
				icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA")
			end
		else
			icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA")
		end
	end
	badge:Show()
end

local function findBlizzardRaidMark(plate, uf)
	local frame = (uf and (uf.RaidTargetFrame or uf.raidTargetFrame)) or (plate and (plate.RaidTargetFrame or plate.raidTargetFrame))
	if frame then
		local tex = frame.RaidTargetIcon or frame.raidTargetIcon or frame.Icon or frame.icon
		return frame, tex
	end
	local tex = (uf and (uf.raidTargetIcon or uf.RaidTargetIcon)) or (plate and (plate.raidTargetIcon or plate.RaidTargetIcon))
	return nil, tex
end

local function positionBlizzardRaidMark(plate, uf)
	if not (plate and uf) then return end
	local bar = uf._HUIBar
	if not bar then return end

	local frame, tex = findBlizzardRaidMark(plate, uf)
	if frame then
		frame:ClearAllPoints()
		frame:SetPoint("BOTTOM", bar, "TOP", 0, 6)
		frame:SetFrameStrata("HIGH")
		frame:SetFrameLevel((bar:GetFrameLevel() or 0) + 50)
		frame:SetSize(RAIDMARK_SIZE, RAIDMARK_SIZE)
	end
	if tex then
		tex:ClearAllPoints()
		tex:SetPoint("BOTTOM", bar, "TOP", 0, 6)
		if tex.SetDrawLayer then tex:SetDrawLayer("OVERLAY", 7) end
		if tex.SetSize then tex:SetSize(RAIDMARK_SIZE, RAIDMARK_SIZE) end
	end
end

local function positionQuestMark(uf)
	local holder = uf and uf._HUIQuestHolder
	local bar = uf and uf._HUIBar
	if not (holder and bar) then return end
	holder:ClearAllPoints()
	holder:SetPoint("BOTTOM", bar, "TOP", 0, 6)
end

local function updateQuestMark() end

local function targetLevelColor(unit, lvl)
	-- Match our target frame rules:
	-- - Friendly units: white
	-- - Neutral/hostile units: level difficulty color (GetQuestDifficultyColor)
	if UnitReaction then
		local reaction = UnitReaction(unit, "player")
		-- 5+ = friendly
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

local function forceHide(f)
	if not f then return end
	if f.UnregisterAllEvents then f:UnregisterAllEvents() end
	if f.Hide then f:Hide() end
	if f.SetScript then
		f:SetScript("OnShow", function(self) self:Hide() end)
	end
end

local function hideNameplateComboPoints()
	-- Try the common layouts across Classic/Retail variants.
	local n = _G.NamePlateDriverFrame
	if not n then return end

	-- Retail-ish
	local bar = n.classNameplateBar
	if bar then
		forceHide(bar.ComboPointFrame)
		forceHide(bar.comboPointFrame)
	end

	-- Some clients expose a single global class bar frame.
	forceHide(_G.ClassNameplateBarFrame and _G.ClassNameplateBarFrame.ComboPointFrame)
	forceHide(_G.ClassNameplateBarFrame and _G.ClassNameplateBarFrame.comboPointFrame)
end

local function safeHide(f)
	if not f then return end
	if f.Hide then f:Hide() end
	if f.SetAlpha then f:SetAlpha(0) end
end

local function expandPlateHitRect(plate)
	if not (plate and plate.SetHitRectInsets) then return end
	-- Negative insets expand the clickable area. Use fixed values (plates can be re-laid out by Blizzard).
	local dw = math.floor((PLATE_W / 2) + 0.5)
	local dh = math.floor((PLATE_H / 2) + 0.5)
	plate:SetHitRectInsets(-dw, -dw, -dh, -dh)
end

local function hideBlizzardQuestMarks(root, depth)
	if not root or depth <= 0 then return end

	-- Common named fields (varies by client/layout).
	local candidates = {
		root.QuestIcon,
		root.questIcon,
		root.QuestIconFrame,
		root.questIconFrame,
		root.QuestIconTexture,
		root.questIconTexture,
	}
	for _, o in ipairs(candidates) do
		if o then
			safeHide(o)
			if o.SetScript then
				o:SetScript("OnShow", function(self) safeHide(self) end)
			end
		end
	end

	-- Hide any textures using the built-in quest icons.
	if root.GetRegions then
		for i = 1, select("#", root:GetRegions()) do
			local r = select(i, root:GetRegions())
			if r and r.GetObjectType and r:GetObjectType() == "Texture" and r.GetTexture then
				local tx = r:GetTexture()
				if type(tx) == "string" then
					if tx:find("GossipFrame\\AvailableQuestIcon", 1, true) or tx:find("GossipFrame\\ActiveQuestIcon", 1, true) then
						safeHide(r)
					end
				end
			end
		end
	end

	if root.GetChildren then
		for i = 1, select("#", root:GetChildren()) do
			hideBlizzardQuestMarks(select(i, root:GetChildren()), depth - 1)
		end
	end
end

local function positionRaidMark(uf) end

local function hideUnknownFontStrings(frame, keepA, keepB, keepC, keepD)
	if not frame or not frame.GetRegions then return end
	for i = 1, select("#", frame:GetRegions()) do
		local r = select(i, frame:GetRegions())
		if r and r.GetObjectType and r:GetObjectType() == "FontString" then
			if r ~= keepA and r ~= keepB and r ~= keepC and r ~= keepD then
				r:Hide()
				if r.SetAlpha then r:SetAlpha(0) end
			end
		end
	end
end

local function hideAllForeignFontStrings(root, keep, depth)
	if not root or depth <= 0 then return end
	if root.GetRegions then
		for i = 1, select("#", root:GetRegions()) do
			local r = select(i, root:GetRegions())
			if r and r.GetObjectType and r:GetObjectType() == "FontString" and not keep[r] then
				r:Hide()
				if r.SetAlpha then r:SetAlpha(0) end
			end
		end
	end
	if root.GetChildren then
		for i = 1, select("#", root:GetChildren()) do
			hideAllForeignFontStrings(select(i, root:GetChildren()), keep, depth - 1)
		end
	end
end

local function ensurePlate(unit)
	if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
	local plate = C_NamePlate.GetNamePlateForUnit(unit)
	if not plate then return end

	local uf = plate.UnitFrame
	if not uf then return end

	if uf.HUIStyled then
		uf._HUIUnit = unit
		expandPlateHitRect(plate)
		positionBlizzardRaidMark(plate, uf)
		-- Quest marks disabled for now.
		hideBlizzardQuestMarks(plate, 3)
		hideBlizzardQuestMarks(uf, 3)
		return uf
	end
	uf.HUIStyled = true
	uf._HUIUnit = unit

	-- Hide Blizzard elements (varies by client/layout).
	safeHide(uf.healthBar)
	safeHide(uf.healthbar)
	safeHide(uf.HealthBar)
	safeHide(uf.castBar)
	safeHide(uf.CastBar)
	safeHide(uf.name)
	safeHide(uf.Name)
	safeHide(uf.level)
	safeHide(uf.Level)
	hideBlizzardQuestMarks(plate, 3)
	hideBlizzardQuestMarks(uf, 3)

	local bar = CreateFrame("StatusBar", nil, uf)
	bar:SetSize(PLATE_W, PLATE_H)
	bar:SetPoint("CENTER", uf, "CENTER", 0, 0)
	-- We handle clicks on a dedicated overlay button.
	if bar.EnableMouse then bar:EnableMouse(false) end
	bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	uf._HUIBar = bar
	expandPlateHitRect(plate)

	-- 3px resource bar below health.
	local res = CreateFrame("StatusBar", nil, uf)
	res:SetHeight(RESOURCE_H)
	res:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0)
	res:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, 0)
	res:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	res:SetMinMaxValues(0, 1)
	res:SetValue(0)
	res:Hide()
	uf._HUIResource = res

	local resBorder = CreateFrame("Frame", nil, res, "BackdropTemplate")
	resBorder:SetAllPoints(res)
	resBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	resBorder:SetBackdropBorderColor(unpack(COLOR_BORDER))
	res._huiBorder = resBorder

	local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
	border:SetAllPoints(bar)
	border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	border:SetBackdropBorderColor(unpack(COLOR_BORDER))
	bar._huiBorder = border

	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	bg:SetAllPoints(bar)
	bg:SetVertexColor(0, 0, 0, 0.6)
	bar._huiBg = bg

	local iconHolder = CreateFrame("Frame", nil, bar)
	iconHolder:SetAllPoints(bar)
	iconHolder:SetFrameLevel((bar:GetFrameLevel() or 0) + 50)
	uf._HUIIconHolder = iconHolder

	local nameText = bar:CreateFontString(nil, "OVERLAY")
	nameText:SetPoint("CENTER", bar, "CENTER", 0, 0)
	nameText:SetJustifyH("CENTER")
	nameText:SetFont(STANDARD_TEXT_FONT, NAME_SIZE, "THICKOUTLINE")
	uf._HUIName = nameText

	local subText = bar:CreateFontString(nil, "OVERLAY")
	subText:SetPoint("BOTTOM", bar, "BOTTOM", 0, 4)
	subText:SetJustifyH("CENTER")
	subText:SetFont(STANDARD_TEXT_FONT, SUB_SIZE, "THICKOUTLINE")
	subText:Hide()
	uf._HUISub = subText

	local levelBadge = CreateFrame("Frame", nil, bar)
	levelBadge:SetSize(LEVEL_BADGE_W, LEVEL_BADGE_H)
	levelBadge:SetPoint("LEFT", bar, "LEFT", 0, 0)
	levelBadge:SetFrameLevel((bar:GetFrameLevel() or 0) + 5)
	uf._HUILevelBadge = levelBadge

	local levelBG = levelBadge:CreateTexture(nil, "BACKGROUND")
	if levelBG.SetAtlas then
		levelBG:SetAtlas("services-ring-countcircle", true)
	else
		levelBG:SetTexture("Interface\\Buttons\\WHITE8x8")
		levelBG:SetVertexColor(0, 0, 0, 0.35)
	end
	levelBG:SetPoint("CENTER", levelBadge, "CENTER", 0, -2)
	levelBG:SetSize(LEVEL_BG_W, LEVEL_BG_H)

	local levelBorder = levelBadge:CreateTexture(nil, "BORDER")
	if levelBorder.SetAtlas then
		levelBorder:SetAtlas("Artifacts-PerkRing-GoldMedal", true)
	else
		levelBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
		levelBorder:SetVertexColor(1, 0.82, 0, 1)
	end
	levelBorder:SetPoint("CENTER", levelBadge, "CENTER", 0.5, 0)
	levelBorder:SetSize(LEVEL_FRAME_W, LEVEL_FRAME_H)
	if levelBorder.SetTexCoord then levelBorder:SetTexCoord(1, 0, 0, 1) end
	levelBorder:Hide()
	uf._HUILevelBorder = levelBorder

	local levelText = levelBadge:CreateFontString(nil, "OVERLAY")
	levelText:SetPoint("CENTER", levelBadge, "CENTER", 0, 0)
	levelText:SetJustifyH("CENTER")
	levelText:SetFont(STANDARD_TEXT_FONT, LEVEL_FONT_SIZE, "THICKOUTLINE")
	uf._HUILevel = levelText

	-- Position Blizzard's raid mark above the bar.
	positionBlizzardRaidMark(plate, uf)

		-- Quest marks disabled for now.

	local pvpBadge = CreateFrame("Frame", nil, bar)
	pvpBadge:SetSize(PVP_BADGE_W, PVP_BADGE_H)
	pvpBadge:SetFrameLevel((bar:GetFrameLevel() or 0) + 6)
	pvpBadge:Hide()
	if uf._HUILevelBadge then
		pvpBadge:SetPoint("RIGHT", uf._HUILevelBadge, "LEFT", PVP_BADGE_GAP, 0)
	else
		pvpBadge:SetPoint("LEFT", bar, "LEFT", 2, 0)
	end
	local pvpIcon = pvpBadge:CreateTexture(nil, "ARTWORK")
	pvpIcon:SetAllPoints(pvpBadge)
	pvpBadge._huiIcon = pvpIcon
	uf._HUIPvPBadge = pvpBadge

	local hpText = bar:CreateFontString(nil, "OVERLAY")
	hpText:SetPoint("RIGHT", bar, "RIGHT", -10, 0)
	hpText:SetJustifyH("RIGHT")
	hpText:SetFont(STANDARD_TEXT_FONT, HP_FONT_SIZE, "THICKOUTLINE")
	uf._HUIHP = hpText

	-- Nuke any leftover Blizzard text (e.g. extra level strings) while keeping ours.
	hideUnknownFontStrings(uf, nameText, subText, levelText, hpText)
	hideUnknownFontStrings(plate, nameText, subText, levelText, hpText)
	hideUnknownFontStrings(bar, nameText, subText, levelText, hpText)
	do
		local keep = { [nameText] = true, [subText] = true, [levelText] = true, [hpText] = true }
		hideAllForeignFontStrings(plate, keep, 4)
	end

	return uf
end

local function updatePlate(unit, what)
	local uf = ensurePlate(unit)
	if not uf then return end

	if not UnitExists(unit) then return end

	-- Follow the same coloring logic as our target healthbar (class/reaction, dim when tapped).
	do
		local r, g, b = unitNameColor(unit)
		if UnitIsTapDenied and UnitIsTapDenied(unit) then
			r, g, b = 0.6, 0.6, 0.6
		end

		local curH = UnitHealth(unit) or 0
		local maxH = UnitHealthMax(unit) or 0
		local pct = 0
		if maxH > 0 then pct = curH / maxH end

		if uf._HUIBar then
			uf._HUIBar:SetStatusBarColor(r, g, b)
			uf._HUIBar:SetValue(pct)
		end
	end

	if not what or what == "name" then
		local name = UnitName(unit) or ""
		local isFriendly = UnitIsFriend and UnitIsFriend("player", unit)

		local showSub = false
		local sub = ""

		if UnitIsPlayer(unit) and isFriendly then
			sub = GetGuildInfo(unit) or ""
			showSub = sub ~= ""
		elseif (not UnitIsPlayer(unit)) and isFriendly then
			sub = getNPCTitle(unit)
			showSub = sub ~= ""
		end

		-- Reposition Blizzard raid mark for this plate (if present).
		if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
			local plate = C_NamePlate.GetNamePlateForUnit(unit)
			if plate then positionBlizzardRaidMark(plate, uf) end
		end
		updatePvPBadge(uf, unit)

		uf._HUIName:ClearAllPoints()
		if showSub then
			uf._HUIName:SetPoint("TOP", uf._HUIBar, "TOP", 0, -4)
			uf._HUISub:Show()
			uf._HUISub:SetText(sub)
		else
			uf._HUIName:SetPoint("CENTER", uf._HUIBar, "CENTER", 0, 0)
			uf._HUISub:Hide()
			uf._HUISub:SetText("")
		end

		local maxW = TEXT_MAX_W
		if uf._HUIRaidMark and uf._HUIRaidMark:IsShown() then
			maxW = maxW - 24
		end
		fitText(uf._HUIName, name, maxW, NAME_SIZE, MIN_NAME_SIZE)
		if showSub then
			fitTwoLine(
				uf._HUIName,
				uf._HUISub,
				name,
				sub,
				maxW,
				NAME_SIZE,
				MIN_NAME_SIZE,
				SUB_SIZE,
				MIN_SUB_SIZE,
				PLATE_H - 10
			)
		end

		local lvl = UnitLevel(unit)
		if not lvl or lvl < 0 then
			uf._HUILevel:SetText("??")
			uf._HUILevel:SetTextColor(1, 0.2, 0.2, 1)
		else
			uf._HUILevel:SetText(tostring(lvl))
			local lr, lg, lb = targetLevelColor(unit, lvl)
			uf._HUILevel:SetTextColor(lr, lg, lb, 1)
		end

		-- Rare/elite/boss indicator ring behavior (same as target frame).
		if uf._HUILevelBorder then
			local classif = UnitClassification and UnitClassification(unit) or "normal"
			if classif == "normal" then
				uf._HUILevelBorder:Hide()
			else
				uf._HUILevelBorder:Show()
				if classif == "rare" then
					if uf._HUILevelBorder.SetDesaturated then uf._HUILevelBorder:SetDesaturated(true) end
					uf._HUILevelBorder:SetVertexColor(0.75, 0.75, 0.75, 1)
				elseif classif == "rareelite" or classif == "elite" or classif == "worldboss" then
					if uf._HUILevelBorder.SetDesaturated then uf._HUILevelBorder:SetDesaturated(false) end
					uf._HUILevelBorder:SetVertexColor(1, 1, 1, 1)
				else
					uf._HUILevelBorder:Hide()
				end
			end
		end

	end

	if not what or what == "health" then
		local hp = UnitHealth(unit) or 0
		local txt, baseDigits = formatHPText(hp)
		uf._HUIHP:SetText(txt)
		fitDigitsText(uf._HUIHP, txt, baseDigits, HP_FONT_SIZE, HP_FONT_MIN)
	end

	if not what or what == "power" then
		local bar = uf._HUIResource
		if bar then
			local cur = UnitPower(unit) or 0
			local max = UnitPowerMax(unit) or 0
			if not max or max <= 0 then
				bar:Hide()
			else
				bar:Show()
				bar:SetMinMaxValues(0, max)
				bar:SetValue(cur)
				local pr, pg, pb = powerColor(unit)
				bar:SetStatusBarColor(pr, pg, pb)
			end
		end
	end
end

local function updateSelectionAlpha()
	if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
	local hasTarget = UnitExists and UnitExists("target")
	local targetUnit = hasTarget and "target" or nil

	for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
		local u = plate and plate.namePlateUnitToken
		if u then
			local uf = ensurePlate(u)
			local bar = uf and uf._HUIBar
			if bar and bar.SetAlpha then
				if targetUnit and UnitIsUnit and UnitIsUnit(u, targetUnit) then
					bar:SetAlpha(1)
				else
					bar:SetAlpha(targetUnit and 0.65 or 1)
				end
			end
		end
	end
end

local function updateAllRaidMarks()
	if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
	for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
		local u = plate and plate.namePlateUnitToken
		if u then
			local uf = ensurePlate(u)
			if uf and plate then positionBlizzardRaidMark(plate, uf) end
		end
	end
end

local function updateAllQuestMarks()
	-- Disabled for now.
end

local function apply()
	hideNameplateComboPoints()

	-- Turn off Blizzard overhead unit names to avoid duplicates with our custom plates.
	local setCVar = (C_CVar and C_CVar.SetCVar) or SetCVar
	if setCVar then
		local function set(name, value)
			pcall(setCVar, name, value)
		end
		set("UnitNameFriendlyPlayerName", "0")
		set("UnitNameFriendlyNPCName", "0")
		set("UnitNameEnemyPlayerName", "0")
		set("UnitNameEnemyNPCName", "0")
		set("UnitNameNPC", "0")

		-- Different clients use different CVars for level display; try all common ones.
		set("UnitNameNPCShowLevel", "0")
		set("UnitNameFriendlyNPCShowLevel", "0")
		set("UnitNameHostileNPCShowLevel", "0")
		set("UnitNameEnemyNPCShowLevel", "0")
		set("UnitNameFriendlyPlayerShowLevel", "0")
		set("UnitNameEnemyPlayerShowLevel", "0")
		set("UnitNameEnemyPlayerShowGuild", "0")

		-- Disable Blizzard quest markers over units (varies by client).
		set("UnitNameNPCShowQuestIcon", "0")
		set("UnitNameNPCShowQuestMarker", "0")
	end

	-- Blizzard recreates/shows these frequently; keep hiding after updates.
	if not M._hooked and hooksecurefunc then
		M._hooked = true
		if _G.NamePlateDriverFrame_UpdateClassNameplateBars then
			hooksecurefunc("NamePlateDriverFrame_UpdateClassNameplateBars", hideNameplateComboPoints)
		end
		if _G.NamePlateDriverFrame then
			hooksecurefunc(_G.NamePlateDriverFrame, "UpdateNamePlateOptions", hideNameplateComboPoints)
		end
	end
end

function M:Apply()
	if not M._ev then
		local ev = CreateFrame("Frame")
		M._ev = ev
		ev:RegisterEvent("PLAYER_ENTERING_WORLD")
		ev:RegisterEvent("PLAYER_TARGET_CHANGED")
		ev:RegisterEvent("RAID_TARGET_UPDATE")
		-- Quest marks disabled for now.
		ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
		ev:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
		ev:RegisterEvent("UNIT_NAME_UPDATE")
		ev:RegisterEvent("UNIT_LEVEL")
		ev:RegisterEvent("UNIT_HEALTH")
		ev:RegisterEvent("UNIT_POWER_UPDATE")
		ev:RegisterEvent("UNIT_POWER_FREQUENT")
		ev:RegisterEvent("UNIT_MAXPOWER")
		ev:RegisterEvent("UNIT_DISPLAYPOWER")
		ev:SetScript("OnEvent", function(_, event, arg1)
			if event == "PLAYER_ENTERING_WORLD" then
				apply()
				if C_NamePlate and C_NamePlate.GetNamePlates then
					for _, p in ipairs(C_NamePlate.GetNamePlates() or {}) do
						local u = p and p.namePlateUnitToken
						if u then updatePlate(u) end
					end
				end
					updateSelectionAlpha()
					updateAllRaidMarks()
					updateAllQuestMarks()
					return
				end
				if event == "PLAYER_TARGET_CHANGED" then
					updateSelectionAlpha()
					updateAllRaidMarks()
					updateAllQuestMarks()
					return
				end
			if event == "RAID_TARGET_UPDATE" then
				updateAllRaidMarks()
				return
			end

			if event == "NAME_PLATE_UNIT_ADDED" then
				updatePlate(arg1)
				updatePlate(arg1, "power")
				updateSelectionAlpha()
				return
			end
			if event == "NAME_PLATE_UNIT_REMOVED" then
				local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(arg1)
				local uf = plate and plate.UnitFrame
				if uf then uf._HUIUnit = nil end
				updateSelectionAlpha()
				return
			end

			if event == "UNIT_HEALTH" then
				updatePlate(arg1, "health")
				return
			end
			if event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
				updatePlate(arg1, "power")
				return
			end
			if event == "UNIT_NAME_UPDATE" or event == "UNIT_LEVEL" then
				updatePlate(arg1, "name")
				return
			end
		end)

		end
		apply()
	end

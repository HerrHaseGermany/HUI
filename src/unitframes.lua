local _, HUI = ...
local U = HUI.util

local M = { name = "unitframes" }
tinsert(HUI.modules, M)

local function setShown(frame, shown)
	if not frame or type(frame) ~= "table" or not frame.Show or not frame.Hide then return end
	if shown then
		frame:Show()
	else
		frame:Hide()
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

local function powerColor(unit)
	local powerType, powerToken = UnitPowerType(unit)
	local c = PowerBarColor[powerToken or powerType]
	if c then return c.r, c.g, c.b end
	return 0.2, 0.4, 1.0
end

local function createBar(parent, height, labelLeft, labelRight)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	bar:SetHeight(height)

	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	bg:SetAllPoints(bar)
	bg:SetVertexColor(0, 0, 0, 0.6)
	bar._huiBg = bg

	local left = U.Font(bar, 12, true)
	left:SetPoint("LEFT", bar, "LEFT", 6, 0)
	left:SetJustifyH("LEFT")
	left:SetText(labelLeft or "")
	bar._huiLeft = left

	local right = U.Font(bar, 12, true)
	right:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
	right:SetJustifyH("RIGHT")
	right:SetText(labelRight or "")
	bar._huiRight = right

	return bar
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
	holder:SetSize(260, 140)
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
	M._huiPlayerHealth = health

	local power = createBar(holder, 18)
	power:SetPoint("TOP", health, "BOTTOM", 0, -4)
	M._huiPlayerPower = power

	local castSlot = CreateFrame("Frame", nil, holder)
	castSlot:SetPoint("TOP", power, "BOTTOM", 0, -4)
	castSlot:SetSize(260, 22)
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
	petButton:SetPoint("TOP", castSlot, "BOTTOM", 0, -4)
	petButton:SetSize(260, 18 + 4 + 14)
	petButton:Hide()
	M._huiPetButton = petButton

	local petHealth = createBar(petButton, 18)
	petHealth:SetPoint("TOP", petButton, "TOP", 0, 0)
	petHealth:Hide()
	M._huiPetHealth = petHealth

	local petPower = createBar(petButton, 14)
	petPower:SetPoint("TOP", petHealth, "BOTTOM", 0, -4)
	petPower:Hide()
	M._huiPetPower = petPower

	-- Mover
	M._huiMover = U.CreateMover("HUI_PlayerUnitFrameMover", "Player Unitframe")
	M._huiMover:Hide()
	M._huiMover._huiOnMoved = function(self)
		local _, _, _, x, y = self:GetPoint(1)
		local db2 = HUI:GetDB()
		db2.unitframes = db2.unitframes or {}
		db2.unitframes.player = db2.unitframes.player or {}
		db2.unitframes.player.x = x
		db2.unitframes.player.y = y
	end

	-- Event driver
	local ev = CreateFrame("Frame")
	M._huiEventFrame = ev
end

local function updateLayout(db)
	local cfg = (db.unitframes and db.unitframes.player) or {}
	local holder = M._huiPlayer
	if not holder then return end

	local w = cfg.w or 260
	local gap = cfg.gap or 4

	local healthH = cfg.healthH or 28
	local powerH = cfg.powerH or 18
	local castH = cfg.castH or 22
	local petHealthH = cfg.petHealthH or 18
	local petPowerH = cfg.petPowerH or 14

	holder:SetSize(w, healthH + gap + powerH + gap + castH + gap + petHealthH + gap + petPowerH)

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

	health:SetWidth(w)
	health:SetHeight(healthH)

	power:SetWidth(w)
	power:SetHeight(powerH)
	power:ClearAllPoints()
	power:SetPoint("TOP", health, "BOTTOM", 0, -gap)

	castSlot:ClearAllPoints()
	castSlot:SetPoint("TOP", power, "BOTTOM", 0, -gap)
	castSlot:SetSize(w, castH)

	cast:SetAllPoints(castSlot)
	wand:SetAllPoints(castSlot)

	local half = math.max(1, math.floor(castH / 2))
	swingMH:SetHeight(half)
	swingOH:SetHeight(half)

	petButton:ClearAllPoints()
	petButton:SetPoint("TOP", castSlot, "BOTTOM", 0, -gap)
	petButton:SetSize(w, petHealthH + gap + petPowerH)

	petHealth:SetWidth(w)
	petHealth:SetHeight(petHealthH)
	petHealth:ClearAllPoints()
	petHealth:SetPoint("TOP", petButton, "TOP", 0, 0)

	petPower:SetWidth(w)
	petPower:SetHeight(petPowerH)
	petPower:ClearAllPoints()
	petPower:SetPoint("TOP", petHealth, "BOTTOM", 0, -gap)

	holder:ClearAllPoints()
	holder:SetPoint("CENTER", UIParent, "CENTER", cfg.x or -260, cfg.y or -220)

	if db.moversUnlocked then
		local mover = M._huiMover
		mover:SetSize(w, healthH + gap + powerH + gap + castH + gap + petHealthH + gap + petPowerH)
		mover:ClearAllPoints()
		mover:SetPoint("CENTER", UIParent, "CENTER", cfg.x or -260, cfg.y or -220)
		mover:Show()
	else
		if M._huiMover then M._huiMover:Hide() end
	end
end

local function updatePlayerBars()
	local health = M._huiPlayerHealth
	local power = M._huiPlayerPower
	if not health or not power then return end

	local lvl = UnitLevel("player") or ""
	if lvl < 0 then lvl = "??" end

	local curH = UnitHealth("player")
	local maxH = UnitHealthMax("player")
	health:SetMinMaxValues(0, math.max(1, maxH or 1))
	health:SetValue(curH or 0)
	health:SetStatusBarColor(0, 1, 0)
	health._huiLeft:SetText(tostring(lvl))
	health._huiRight:SetText(formatHealth(curH, maxH))

	local curP = UnitPower("player")
	local maxP = UnitPowerMax("player")
	power:SetMinMaxValues(0, math.max(1, maxP or 1))
	power:SetValue(curP or 0)
	local pr, pg, pb = powerColor("player")
	power:SetStatusBarColor(pr, pg, pb)
	if maxP and maxP > 0 then
		power._huiRight:SetText(string.format("%s/%s (%.0f%%)", shortNumber(curP), shortNumber(maxP), (curP / maxP) * 100))
	else
		power._huiRight:SetText("")
	end
	power._huiLeft:SetText("")
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
	petHealth._huiRight:SetText(formatHealth(curH, maxH))

	local curP = UnitPower("pet")
	local maxP = UnitPowerMax("pet")
	petPower:SetMinMaxValues(0, math.max(1, maxP or 1))
	petPower:SetValue(curP or 0)
	local pr, pg, pb = powerColor("pet")
	petPower:SetStatusBarColor(pr, pg, pb)
	if maxP and maxP > 0 then
		petPower._huiRight:SetText(string.format("%s/%s (%.0f%%)", shortNumber(curP), shortNumber(maxP), (curP / maxP) * 100))
	else
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

local function applyEnabled(db, enabled)
	ensureFrames()
	if not M._huiPlayer then return end

	if not enabled then
		M._huiPlayer:Hide()
		if M._huiMover then M._huiMover:Hide() end
		if M._huiEventFrame then
			M._huiEventFrame:SetScript("OnEvent", nil)
			M._huiEventFrame:SetScript("OnUpdate", nil)
			M._huiEventFrame:UnregisterAllEvents()
		end
		return
	end

	updateLayout(db)
	M._huiPlayer:Show()
	updatePlayerBars()
	updatePetBars()
	updateCastOrTimers()

	local ev = M._huiEventFrame
	ev:UnregisterAllEvents()
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:RegisterEvent("START_AUTOREPEAT_SPELL")
	ev:RegisterEvent("STOP_AUTOREPEAT_SPELL")
	ev:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	ev:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", "player", "pet")
	ev:RegisterUnitEvent("UNIT_MAXHEALTH", "player", "pet")
	ev:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player", "pet")
	ev:RegisterUnitEvent("UNIT_MAXPOWER", "player", "pet")
	ev:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player", "pet")
	ev:RegisterEvent("UNIT_PET")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")

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
		if unit == "player" or event == "PLAYER_ENTERING_WORLD" then
			updatePlayerBars()
			updateCastOrTimers()
		end
		if unit == "pet" or event == "PLAYER_ENTERING_WORLD" then
			updatePetBars()
		end
		if event == "START_AUTOREPEAT_SPELL" or event == "STOP_AUTOREPEAT_SPELL" then
			updateCastOrTimers()
		end
	end)
	ev:SetScript("OnUpdate", function()
		updateCastOrTimers()
	end)
end

function M:Apply(db)
	db = db or HUI:GetDB()
	db.enable = db.enable or {}

	-- Unit frames are protected; avoid combat lockdown issues.
	if InCombatLockdown and InCombatLockdown() then return end

	local useCustom = db.enable.unitframes and true or false

	-- Hide Blizzard when using custom.
	setShown(_G.PlayerFrame, not useCustom)
	setShown(_G.TargetFrame, not useCustom)
	setShown(_G.TargetFrameToT, not useCustom)
	setShown(_G.FocusFrame, not useCustom)

	applyEnabled(db, useCustom)
end

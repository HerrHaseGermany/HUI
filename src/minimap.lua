local ADDON_NAME, HUI = ...

local M = { name = "minimap" }
table.insert(HUI.modules, M)

local holder
local initialized = false

local MINIMAP_SIZE = 250
local BORDER_SIZE = 2
local CLOCK_SCALE = 1.5
local CLOCK_BG_PAD = 2

local function safeHide(frame)
	if not frame then return end
	if frame.UnregisterAllEvents then frame:UnregisterAllEvents() end
	if frame.Hide then frame:Hide() end
	if frame.SetShown then frame:SetShown(false) end
end

local function ensureHolder()
	if holder then return holder end
	holder = CreateFrame("Frame", "HUI_MinimapHolder", UIParent, "BackdropTemplate")
	holder:SetSize(MINIMAP_SIZE + (BORDER_SIZE * 2), MINIMAP_SIZE + (BORDER_SIZE * 2))
	holder:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -5, 26)
	holder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = BORDER_SIZE })
	holder:SetBackdropBorderColor(0, 0, 0, 1)
	holder:SetBackdropColor(0, 0, 0, 0)
	return holder
end

local function ensureClock()
	if TimeManagerClockButton then return TimeManagerClockButton end
	if UIParentLoadAddOn then pcall(UIParentLoadAddOn, "Blizzard_TimeManager") end
	return TimeManagerClockButton
end

local function stripClockTextures(clock)
	if not clock then return end
	local function clearButtonTexture(getter, setter)
		if type(getter) == "function" then
			local tex = getter(clock)
			if tex and tex.SetTexture then tex:SetTexture(nil) end
		end
		if type(setter) == "function" then
			pcall(setter, clock, "")
		end
	end

	clearButtonTexture(clock.GetNormalTexture, clock.SetNormalTexture)
	clearButtonTexture(clock.GetPushedTexture, clock.SetPushedTexture)
	clearButtonTexture(clock.GetHighlightTexture, clock.SetHighlightTexture)
	clearButtonTexture(clock.GetDisabledTexture, clock.SetDisabledTexture)

	for i = 1, select("#", clock:GetRegions()) do
		local region = select(i, clock:GetRegions())
		if region and region.GetObjectType and region:GetObjectType() == "Texture" then
			region:SetTexture(nil)
			region:Hide()
		end
	end
end

-- (minimap corner button removed for now)

local function ensureClockBackground(clock)
	if not clock then return end
	if clock.GetWidth and clock:GetWidth() == 0 then
		clock:SetSize(44, 14)
	end

	local textRegion
	for i = 1, select("#", clock:GetRegions()) do
		local region = select(i, clock:GetRegions())
		if region and region.GetObjectType and region:GetObjectType() == "FontString" then
			textRegion = region
			break
		end
	end

	if textRegion then
		if textRegion.ClearAllPoints and textRegion.SetPoint then
			textRegion:ClearAllPoints()
			textRegion:SetPoint("CENTER", clock, "CENTER", 0, 0)
		end
		if textRegion.SetJustifyH then textRegion:SetJustifyH("CENTER") end
		if textRegion.SetJustifyV then textRegion:SetJustifyV("MIDDLE") end
	end

	local f = clock._huiBg
	if not f then
		f = CreateFrame("Frame", nil, clock, "BackdropTemplate")
		f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
		f:SetBackdropColor(0, 0, 0, 0.6)
		if f.SetFrameLevel and clock.GetFrameLevel then
			f:SetFrameLevel(math.max((clock:GetFrameLevel() or 1) - 1, 0))
		end
		f:Show()
		clock._huiBg = f
	end

	f:ClearAllPoints()
	f:SetPoint("CENTER", clock, "CENTER", 0, 0)
	do
		local w, h = 44, 14
		if textRegion and textRegion.GetStringWidth and textRegion.GetStringHeight then
			w = math.max(w, textRegion:GetStringWidth() + (CLOCK_BG_PAD * 1))
			h = math.max(h, textRegion:GetStringHeight() + (CLOCK_BG_PAD * 2))
		end
		f:SetSize(w, h)
	end
end

local function applyOnce()
	if initialized then return end
	initialized = true

	Minimap:EnableMouseWheel(true)
	Minimap:SetScript("OnMouseWheel", function(_, delta)
		if delta > 0 then
			if Minimap_ZoomIn then
				Minimap_ZoomIn()
			else
				Minimap:SetZoom(math.min((Minimap:GetZoom() or 0) + 1, (Minimap:GetZoomLevels() or 5) - 1))
			end
		else
			if Minimap_ZoomOut then
				Minimap_ZoomOut()
			else
				Minimap:SetZoom(math.max((Minimap:GetZoom() or 0) - 1, 0))
			end
		end
	end)

	safeHide(MinimapBorder)
	safeHide(MinimapBorderTop)
	safeHide(MinimapZoomIn)
	safeHide(MinimapZoomOut)
	safeHide(MinimapZoneTextButton)
	safeHide(MinimapZoneText)
	safeHide(MinimapToggleButton)
	safeHide(MiniMapWorldMapButton)
	safeHide(MinimapNorthTag)

	if MinimapCluster then
		MinimapCluster:EnableMouse(false)
		MinimapCluster:SetAlpha(0)
	end
end

local function dockIndicator(frame, parent, point, relTo, relPoint, x, y, scale)
	if not frame then return end
	local wasShown = frame.IsShown and frame:IsShown()
	parent = parent or UIParent
	relTo = relTo or parent
	-- Guard against bad anchor strings (some frames override SetPoint erroring hard).
	relPoint = relPoint or point
	-- Prevent Blizzard's frame position manager from moving it back.
	frame.ignoreFramePositionManager = true
	if frame.SetParent then frame:SetParent(parent) end
	if frame.SetFrameStrata then frame:SetFrameStrata("HIGH") end
	if frame.SetFrameLevel and relTo.GetFrameLevel then
		frame:SetFrameLevel((relTo:GetFrameLevel() or 0) + 80)
	end
	if frame.ClearAllPoints then frame:ClearAllPoints() end
	if frame.SetPoint then
		pcall(frame.SetPoint, frame, point, relTo, relPoint, x or 0, y or 0)
	end
	if frame.SetScale and scale then frame:SetScale(scale) end
	-- Don't force-show indicators; otherwise you get empty/placeholder buttons.
	if wasShown and frame.SetAlpha then frame:SetAlpha(1) end
	if wasShown and frame.Show then frame:Show() end
end

local function dockMinimapIndicators(holderFrame)
	-- Stack common minimap indicators on the left side of the frame.
	local function firstAvailable(...)
		for i = 1, select("#", ...) do
			local f = select(i, ...)
			if f then return f end
		end
		return nil
	end

	-- Only pick one per "type" to avoid duplicates/empty shells on some clients.
	local stack = {
		firstAvailable(_G.MiniMapMailFrame), -- mail
		firstAvailable(_G.QueueStatusMinimapButton, _G.LFGMinimapFrame), -- queue/LFG
		firstAvailable(_G.MiniMapTrackingButton, _G.MiniMapTracking, _G.MiniMapTrackingFrame), -- tracking
	}

	local shown = {}
	local totalH = 0
	local gap = 2
	for i = 1, #stack do
		local f = stack[i]
		if f and f.IsShown and f:IsShown() then
			local h = (f.GetHeight and f:GetHeight()) or 20
			shown[#shown + 1] = { f = f, h = h }
			totalH = totalH + h
		end
	end
	if #shown > 1 then
		totalH = totalH + ((#shown - 1) * gap)
	end

	-- Center the stack vertically on the holder.
	local y = (totalH / 2) - ((shown[1] and shown[1].h) or 20) / 2
	for i = 1, #shown do
		local item = shown[i]
		dockIndicator(item.f, holderFrame, "CENTER", holderFrame, "LEFT", 0, y, 0.9)
		y = y - item.h - gap
	end

	-- Durability/repair indicator: move it down ~60px so it doesn't sit on the minimap center.
	dockIndicator(_G.DurabilityFrame, holderFrame, "TOPLEFT", holderFrame, "TOPLEFT", -200, -50, 1)
end

local function ensureIndicatorDocking(holderFrame)
	if M._huiDockHooked then return end
	M._huiDockHooked = true

	-- Blizzard can reposition minimap indicators after we dock them (login, state changes, etc).
	-- Re-dock whenever the frame position manager runs.
	if hooksecurefunc then
		hooksecurefunc("UIParent_ManageFramePositions", function()
			if holder then dockMinimapIndicators(holder) end
		end)
	end

	-- Also nudge for a short time after apply to win races with late-loading Blizzard code.
	if C_Timer and C_Timer.NewTicker then
		if M._dockTicker then
			M._dockTicker:Cancel()
			M._dockTicker = nil
		end
		local ticks = 0
		M._dockTicker = C_Timer.NewTicker(0.2, function()
			ticks = ticks + 1
			if holder then dockMinimapIndicators(holder) end
			if ticks >= 25 then
				if M._dockTicker then M._dockTicker:Cancel() end
				M._dockTicker = nil
			end
		end)
	end
end

function M:Apply(db)
	if db and db.enable and db.enable.minimap == false then return end

	applyOnce()

	local h = ensureHolder()

	Minimap:SetParent(h)
	Minimap:ClearAllPoints()
	Minimap:SetPoint("TOPLEFT", h, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
	Minimap:SetSize(MINIMAP_SIZE, MINIMAP_SIZE)
	if Minimap.SetMaskTexture then
		Minimap:SetMaskTexture("Interface\\ChatFrame\\ChatFrameBackground")
	end

	dockMinimapIndicators(h)
	ensureIndicatorDocking(h)

	local clock = ensureClock()
	if clock then
		stripClockTextures(clock)
		ensureClockBackground(clock)
		if not clock._huiScaled and clock.SetScale then
			clock:SetScale(CLOCK_SCALE)
			clock._huiScaled = true
		end
		clock:SetParent(Minimap)
		if clock.SetFrameStrata then clock:SetFrameStrata("HIGH") end
		if clock.SetFrameLevel and Minimap.GetFrameLevel then
			clock:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 50)
		end
		clock:ClearAllPoints()
		clock:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", -8, -8)
	end

	-- (minimap corner button removed for now)
end

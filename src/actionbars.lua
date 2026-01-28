local ADDON_NAME, HUI = ...
local U = HUI.util

local M = { name = "actionbars" }
table.insert(HUI.modules, M)

local orig
local layoutPrimary

-- Pet bar placement (separate from other class bars).
local PETBAR_X = 0
local PETBAR_Y_OFFSET = 0
local PETBAR_ANCHOR_TO_BAR3 = true

local function placePetBar()
	if not PetActionBarFrame or not PetActionBarFrame.ClearAllPoints then return end
	if InCombatLockdown and InCombatLockdown() then return end

	local function stopSlide(frame)
		if not frame then return end
		if frame.slideOut and frame.slideOut.Stop then frame.slideOut:Stop() end
		if frame.slideIn and frame.slideIn.Stop then frame.slideIn:Stop() end
	end

	-- Blizzard sometimes animates/relocates the pet bar; stop slide animations and re-anchor.
	stopSlide(PetActionBarFrame)

	PetActionBarFrame.ignoreFramePositionManager = true
	PetActionBarFrame:ClearAllPoints()

	local x = PETBAR_X or 0
	local y = PETBAR_Y_OFFSET or 0

	-- Prefer anchoring to bar 3 directly so it always stacks correctly regardless of scale/height.
	if PETBAR_ANCHOR_TO_BAR3 and MultiBarBottomRight and MultiBarBottomRight.GetTop then
		PetActionBarFrame:SetPoint("BOTTOM", MultiBarBottomRight, "TOP", x, y)
	else
		-- Fallback: stack above bar 3 using screen coordinates.
		local bar3H = (MultiBarBottomRight and MultiBarBottomRight.GetHeight and MultiBarBottomRight:GetHeight()) or 48
		PetActionBarFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", x, (BAR3_Y or 0) + bar3H + (BAR_GAP_Y or 0) + y)
	end

	-- Also pin other class/extra bars to the same spot (they are mutually exclusive most of the time).
	local function placeAtPetPos(frame)
		if not frame or not frame.ClearAllPoints then return end
		stopSlide(frame)
		frame.ignoreFramePositionManager = true
		frame:ClearAllPoints()
		if PETBAR_ANCHOR_TO_BAR3 and MultiBarBottomRight and MultiBarBottomRight.GetTop then
			frame:SetPoint("BOTTOM", MultiBarBottomRight, "TOP", x, y)
		else
			local bar3H = (MultiBarBottomRight and MultiBarBottomRight.GetHeight and MultiBarBottomRight:GetHeight()) or 48
			frame:SetPoint("BOTTOM", UIParent, "BOTTOM", x, (BAR3_Y or 0) + bar3H + (BAR_GAP_Y or 0) + y)
		end
	end

	placeAtPetPos(_G.StanceBarFrame)
	placeAtPetPos(_G.PossessBarFrame)
	placeAtPetPos(_G.MultiCastActionBarFrame)
end

local function nudgePetBar()
	-- Blizzard can re-anchor the pet bar a few frames after show; re-apply briefly.
	if not C_Timer or not C_Timer.NewTicker then return end
	if M._petNudgeTicker then
		M._petNudgeTicker:Cancel()
		M._petNudgeTicker = nil
	end
	local ticks = 0
	M._petNudgeTicker = C_Timer.NewTicker(0.1, function()
		ticks = ticks + 1
		placePetBar()
		if ticks >= 20 then
			if M._petNudgeTicker then M._petNudgeTicker:Cancel() end
			M._petNudgeTicker = nil
		end
	end)
end

	-- Hardcoded layout: edit these numbers (no in-game movers/options).
	local BAR_SCALE = 1
	local BUTTON_SIZE = 40
	local BUTTON_GAP = 7
	local BAR_GAP_X = 6
	local BAR_GAP_Y = 0

		local BAR1_X, BAR1_Y = 0, 46
	local BAR2_X, BAR2_Y = BAR1_X, BAR1_Y + BUTTON_SIZE + BUTTON_GAP + BAR_GAP_Y
	local BAR3_X, BAR3_Y = BAR1_X, BAR2_Y + BUTTON_SIZE + BUTTON_GAP + BAR_GAP_Y

-- Class-dependent row (pet/stance/possess/totem) sits above bar 3.
local CLASSBAR_X, CLASSBAR_Y = 0, 0

-- Bag bar (backpack + 4 bag slots)
local BAGS_POINT, BAGS_RELPOINT = "BOTTOMRIGHT", "BOTTOMRIGHT"
local BAGS_X, BAGS_Y = 0, 37
local BAGS_SCALE = 1.2
local BAGS_GAP_X = 4
local BAGS_SHOW_ONLY_BACKPACK = true

local art = {
	MainMenuBarArtFrameBackground,
	MainMenuBarArtFrame and MainMenuBarArtFrame.LeftEndCap or nil,
	MainMenuBarArtFrame and MainMenuBarArtFrame.RightEndCap or nil,
	SlidingActionBarTexture0,
	SlidingActionBarTexture1,
	MainMenuBarTexture0,
	MainMenuBarTexture1,
	MainMenuBarTexture2,
	MainMenuBarTexture3,
	ActionBarUpButton,
	ActionBarDownButton,
	MainMenuBarPageNumber,
	MainMenuBarVehicleLeaveButton,
	ExhaustionTick,
	ExhaustionLevelFillBar,
}

local function safe(obj)
	return obj and obj.ClearAllPoints and obj.SetPoint and obj.SetScale
end

local function hideArt()
	-- IMPORTANT: do not hide parent frames like MainMenuBarArtFrame, or the buttons disappear.
	-- Instead, hide textures/regions within those frames.
	local function hideRegions(frame)
		if not frame or not frame.GetRegions then return end
		for _, r in ipairs({ frame:GetRegions() }) do
			if r and r.GetObjectType and r:GetObjectType() == "Texture" and r.Hide then
				r:Hide()
			end
		end
	end

	hideRegions(_G.MainMenuBarArtFrame)
	hideRegions(_G.MainMenuBarOverlayFrame)
	hideRegions(_G.StatusTrackingBarManager)

	for _, t in ipairs(art) do
		U.SafeHide(t)
	end

	-- Page arrows are sometimes re-shown by Blizzard; force-hide them.
	if _G.ActionBarUpButton then
		_G.ActionBarUpButton:Hide()
		_G.ActionBarUpButton:SetScript("OnShow", function(self) self:Hide() end)
	end
	if _G.ActionBarDownButton then
		_G.ActionBarDownButton:Hide()
		_G.ActionBarDownButton:SetScript("OnShow", function(self) self:Hide() end)
	end
	if _G.MainMenuBarPageNumber then
		_G.MainMenuBarPageNumber:Hide()
		_G.MainMenuBarPageNumber:SetScript("OnShow", function(self) self:Hide() end)
	end
end

local function showArt()
	for _, t in ipairs(art) do
		if t and t.Show then t:Show() end
	end
end

local function disableXPBars()
	-- Fully disable Blizzard XP/Rep/Honor bars.
	if U and U.UnregisterAndHide then
		U.UnregisterAndHide(_G.StatusTrackingBarManager)
		U.UnregisterAndHide(_G.MainMenuExpBar)
		U.UnregisterAndHide(_G.ReputationWatchBar)
		U.UnregisterAndHide(_G.HonorWatchBar)
	else
		if _G.StatusTrackingBarManager then _G.StatusTrackingBarManager:Hide() end
		if _G.MainMenuExpBar then _G.MainMenuExpBar:Hide() end
		if _G.ReputationWatchBar then _G.ReputationWatchBar:Hide() end
		if _G.HonorWatchBar then _G.HonorWatchBar:Hide() end
	end
end

local function disableLatencyBar()
	-- The small latency/performance bar that can appear near the action bars.
	if U and U.UnregisterAndHide then
		U.UnregisterAndHide(_G.MainMenuBarPerformanceBarFrame)
		U.UnregisterAndHide(_G.MainMenuBarPerformanceBar)
	else
		if _G.MainMenuBarPerformanceBarFrame then _G.MainMenuBarPerformanceBarFrame:Hide() end
		if _G.MainMenuBarPerformanceBar then _G.MainMenuBarPerformanceBar:Hide() end
	end
end

local function ensurePositionHook()
	if M._huiHookedPositions then return end
	M._huiHookedPositions = true
	if not hooksecurefunc then return end
	-- Blizzard frequently re-runs the frame position manager and can re-anchor bars together.
	-- Re-apply our layout after each pass (out of combat).
	hooksecurefunc("UIParent_ManageFramePositions", function()
		if InCombatLockdown and InCombatLockdown() then return end
		if layoutPrimary then layoutPrimary(HUI:GetDB().actionbars or {}) end
		placePetBar()
		disableXPBars()
		disableLatencyBar()
	end)
end

local function ensurePetVisibilityHook()
	if M._huiHookedPetVis then return end
	M._huiHookedPetVis = true

	local ev = CreateFrame("Frame")
	M._petEv = ev
	ev:RegisterEvent("ADDON_LOADED")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:RegisterEvent("UNIT_PET")
	ev:RegisterEvent("PLAYER_REGEN_ENABLED")
	ev:SetScript("OnEvent", function(_, event, a1)
		if event == "ADDON_LOADED" and a1 ~= "Blizzard_ActionBar" then return end
		local unit = a1
		if event == "UNIT_PET" and unit ~= "player" then return end
		if InCombatLockdown and InCombatLockdown() then
			M._pendingPetLayout = true
			return
		end
		if event == "PLAYER_REGEN_ENABLED" and not M._pendingPetLayout then return end
		M._pendingPetLayout = nil
		if layoutPrimary then layoutPrimary(HUI:GetDB().actionbars or {}) end
		placePetBar()
		nudgePetBar()
	end)

	if hooksecurefunc and not M._huiHookedPetUpdate then
		M._huiHookedPetUpdate = true
		if PetActionBar_UpdatePosition then
			hooksecurefunc("PetActionBar_UpdatePosition", function()
				placePetBar()
				nudgePetBar()
			end)
		end
	end

	-- When the pet bar becomes visible later, re-anchor it immediately.
	if _G.PetActionBarFrame and _G.PetActionBarFrame.HookScript and not M._huiHookedPetOnShow then
		M._huiHookedPetOnShow = true
		_G.PetActionBarFrame:HookScript("OnShow", function()
			placePetBar()
			nudgePetBar()
		end)
	end
end

local function snapshot()
	if orig then return end
	orig = {}
	local function snapFrame(key, f)
		if not safe(f) then return end
		local p = { f:GetPoint(1) }
		orig[key] = { point = p, scale = f:GetScale() }
	end
	snapFrame("MainMenuBar", MainMenuBar)
	snapFrame("MultiBarBottomLeft", MultiBarBottomLeft)
	snapFrame("MultiBarBottomRight", MultiBarBottomRight)
	snapFrame("MultiBarRight", MultiBarRight)
	snapFrame("MultiBarLeft", MultiBarLeft)
end

local function restore()
	if InCombatLockdown() then return end
	if not orig then return end
	local function restoreFrame(key, f)
		local o = orig[key]
		if not o or not safe(f) then return end
		f:ClearAllPoints()
		if o.point and o.point[1] then f:SetPoint(unpack(o.point)) end
		f:SetScale(o.scale or 1)
	end
	restoreFrame("MainMenuBar", MainMenuBar)
	restoreFrame("MultiBarBottomLeft", MultiBarBottomLeft)
	restoreFrame("MultiBarBottomRight", MultiBarBottomRight)
	restoreFrame("MultiBarRight", MultiBarRight)
	restoreFrame("MultiBarLeft", MultiBarLeft)
	showArt()
end

local function applyFrame(frame, point, relPoint, x, y, scale)
	if not safe(frame) then return end
	if InCombatLockdown() then return end

	frame:ClearAllPoints()
	frame:SetPoint(point, UIParent, relPoint, x or 0, y or 0)
	frame:SetScale(scale or 1)
end

	local function layoutButtonGrid(frame, buttonPrefix, cols, rows, gap)
		if InCombatLockdown() then return end
		if not frame or not buttonPrefix then return end
		cols = cols or 12
		rows = rows or 1
		gap = gap or BUTTON_GAP or 0

	local b1 = _G[buttonPrefix .. "1"]
	if not b1 or not b1.GetWidth then return end

		local bw = BUTTON_SIZE or (b1:GetWidth() or 0)
		local bh = BUTTON_SIZE or (b1:GetHeight() or 0)
		if bw <= 0 or bh <= 0 then bw, bh = 36, 36 end

	if frame.SetSize then
		frame:SetSize(cols * bw + (cols - 1) * gap, rows * bh + (rows - 1) * gap)
	end

		for i = 1, cols * rows do
			local btn = _G[buttonPrefix .. i]
			if btn and btn.ClearAllPoints then
				if btn.SetSize then btn:SetSize(bw, bh) end
				btn:ClearAllPoints()
				local c = (i - 1) % cols
				local r = math.floor((i - 1) / cols)
				btn:SetPoint("TOPLEFT", frame, "TOPLEFT", c * (bw + gap), -r * (bh + gap))
			end
		end
	end

			local function skinActionButton(btn)
				-- User requested: remove all custom button/background styling.
				-- Keep a tiny cleanup to hide any previously-created custom frames until next /reload.
				if not btn then return end
				if btn._HUIBG and btn._HUIBG.Hide then btn._HUIBG:Hide() end
				local nt = btn.GetNormalTexture and btn:GetNormalTexture()
				if nt and nt.SetAlpha then nt:SetAlpha(1) end
			end

			local function skinButtons(prefix, count)
				for i = 1, count do
					skinActionButton(_G[prefix .. i])
				end
			end

				local function ensureBar1StaticGrid()
					-- (Disabled) custom always-on bar1 grid.
					if M._huiBar1Grid and M._huiBar1Grid.Hide then M._huiBar1Grid:Hide() end
				end

			local function ensureGridHooks() end

			local function forceGrid() end

local function applyBagBar()
	if InCombatLockdown() then return end

	local anchor = _G.MainMenuBarBackpackButton or _G.MainMenuBarBackpackButton
	if not anchor or not anchor.ClearAllPoints then return end

	anchor:ClearAllPoints()
	anchor:SetPoint(BAGS_POINT, UIParent, BAGS_RELPOINT, BAGS_X, BAGS_Y)
	anchor:SetScale(BAGS_SCALE)

	if BAGS_SHOW_ONLY_BACKPACK then
		for i = 0, 3 do
			local bag = _G["CharacterBag" .. i .. "Slot"]
			if bag then
				if bag.Hide then bag:Hide() end
				if bag.SetScript then
					bag:SetScript("OnShow", function(self) self:Hide() end)
				end
			end
		end
		-- Some clients have a bag-bar expand/collapse button.
		if _G.BagBarExpandToggle then
			_G.BagBarExpandToggle:Hide()
			_G.BagBarExpandToggle:SetScript("OnShow", function(self) self:Hide() end)
		end
	else
		local prev = anchor
		for i = 0, 3 do
			local bag = _G["CharacterBag" .. i .. "Slot"]
			if bag and bag.ClearAllPoints then
				if bag.SetScript then bag:SetScript("OnShow", nil) end
				bag:Show()
				bag:ClearAllPoints()
				bag:SetPoint("LEFT", prev, "RIGHT", BAGS_GAP_X, 0)
				bag:SetScale(BAGS_SCALE)
				prev = bag
			end
		end
	end
end

	layoutPrimary = function(cfg)
			if not safe(MainMenuBar) then return end
			if InCombatLockdown() then return end

	local function detach(frame)
		if not frame then return end
		if frame.SetParent then frame:SetParent(UIParent) end
		-- Prevent UIParent frame position manager from moving it back.
		frame.ignoreFramePositionManager = true
		-- Some protected frames (e.g. MainMenuBar) error/taint on SetUserPlaced.
		if frame.SetUserPlaced and frame.IsMovable and frame:IsMovable() then
			frame:SetUserPlaced(true)
		end
	end

	MainMenuBar:EnableMouse(false)
	-- Detach primary action bars from Blizzard art/managed parents so they can be positioned independently.
	-- NOTE: Do NOT detach class bars (pet/stance/possess/totem). Their visibility is driven by secure
	-- Blizzard state, and reparenting can cause them to get stuck hidden on Classic.
	detach(MainMenuBar)
	detach(MultiBarBottomLeft)
	detach(MultiBarBottomRight)
		detach(MultiBarRight)
		detach(MultiBarLeft)

		applyFrame(MainMenuBar, "BOTTOM", "BOTTOM", BAR1_X, BAR1_Y, BAR_SCALE)
		layoutButtonGrid(MainMenuBar, "ActionButton", 12, 1, BUTTON_GAP)
		if safe(MultiBarBottomLeft) then
			applyFrame(MultiBarBottomLeft, "BOTTOM", "BOTTOM", BAR2_X, BAR2_Y, BAR_SCALE)
			layoutButtonGrid(MultiBarBottomLeft, "MultiBarBottomLeftButton", 12, 1, BUTTON_GAP)
		end
		if safe(MultiBarBottomRight) then
			applyFrame(MultiBarBottomRight, "BOTTOM", "BOTTOM", BAR3_X, BAR3_Y, BAR_SCALE)
			layoutButtonGrid(MultiBarBottomRight, "MultiBarBottomRightButton", 12, 1, BUTTON_GAP)
		end
		-- Bar 4/5: 4x3 grids anchored to the right edge of bar 3 (matching the mockup).
		if safe(MultiBarRight) and safe(MultiBarBottomRight) then
			MultiBarRight:ClearAllPoints()
				MultiBarRight:SetPoint("BOTTOMLEFT", MultiBarBottomRight, "TOPRIGHT", 6, 6)
			MultiBarRight:SetScale(BAR_SCALE)
			layoutButtonGrid(MultiBarRight, "MultiBarRightButton", 4, 3, BUTTON_GAP)
		end
		if safe(MultiBarLeft) and safe(MultiBarRight) then
			MultiBarLeft:ClearAllPoints()
			MultiBarLeft:SetPoint("BOTTOMLEFT", MultiBarRight, "TOPLEFT", 0, BUTTON_GAP + BAR_GAP_Y)
			MultiBarLeft:SetScale(BAR_SCALE)
			layoutButtonGrid(MultiBarLeft, "MultiBarLeftButton", 4, 3, BUTTON_GAP)
		end

		-- Class/extra bars (pet/stance/possess/totem + extra action bars) share the pet-bar position.
		placePetBar()

	applyBagBar()
end

		function M:Apply(db)
			ensurePositionHook()
			ensurePetVisibilityHook()
			snapshot()
			hideArt()
			layoutPrimary(db.actionbars or {})
			disableXPBars()
			disableLatencyBar()
		end

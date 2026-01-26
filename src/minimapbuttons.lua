local ADDON_NAME, HUI = ...

local M = { name = "minimapbuttons" }
table.insert(HUI.modules, M)

local toggleButton
local window
local container
local collected = {}
local collectedList = {}
local collectedVisible = {}
local pendingToggle

local EDGE_SIZE = 16
local EDGE_INSET = 4
local LOGO_SIZE = 44

local BUTTON_SIZE = 32
local PADDING = EDGE_INSET
local GAP = 0
local COLUMNS = 7
local HEADER_H = 6

local function getPlayerColor()
	local _, class = UnitClass and UnitClass("player")
	local palette = type(CUSTOM_CLASS_COLORS) == "table" and CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
	local c = class and palette and palette[class]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

local function getChildren(frame)
	if not frame or not frame.GetChildren then return nil end
	return { frame:GetChildren() }
end

local function isMinimapButton(btn)
	if not btn or btn == toggleButton then return false end
	if TimeManagerClockButton and btn == TimeManagerClockButton then return false end
	if btn.IsForbidden and btn:IsForbidden() then return false end
	if type(btn) ~= "table" then return false end
	if btn.IsObjectType and not btn:IsObjectType("Frame") then return false end

	local name = btn.GetName and btn:GetName()
	if not name then return false end

	-- Ported from MinimapButtonButton (Classic).
	if name == "TimeManagerClockButton" then return false end
	if issecurevariable and issecurevariable(_G, name) then return false end

	-- TomCats buttons can end with the current year.
	if name:match("^TomCats%-") then return true end

	-- Avoid collecting numbered frames (often internal children), except LibDBIcon.
	if not name:match("^LibDBIcon10_") and name:match("%d$") then return false end

	if name:match("^LibDBIcon10_") then return true end
	if name:match("MinimapButton") then return true end
	if name:match("MinimapFrame") then return true end
	if name:match("MinimapIcon") then return true end
	if name:match("[-_]Minimap[-_]") then return true end
	if name:match("Minimap$") then return true end

	return false
end

local function getLibDBIcon()
	return LibStub and LibStub.GetLibrary and LibStub:GetLibrary("LibDBIcon-1.0", true) or nil
end

local function getLibMapButton()
	return LibStub and LibStub.GetLibrary and LibStub:GetLibrary("LibMapButton-1.1", true) or nil
end

local function bringTooltipToFront()
	local tt = GameTooltip
	if not tt or not tt.SetFrameLevel then return end
	if tt.SetFrameStrata then tt:SetFrameStrata("TOOLTIP") end
	local target = M._huiTooltipLevel
	if not target then
		local w = window
		target = ((w and w.GetFrameLevel and w:GetFrameLevel()) or 0) + 200
	end
	if not tt.GetFrameLevel or tt:GetFrameLevel() < target then
		tt:SetFrameLevel(target)
	end
	if tt.Raise then tt:Raise() end
end

local function hookTooltip()
	if M._huiTooltipHooked then return end
	M._huiTooltipHooked = true
	if hooksecurefunc and GameTooltip then
		hooksecurefunc(GameTooltip, "SetOwner", bringTooltipToFront)
		hooksecurefunc(GameTooltip, "Show", bringTooltipToFront)
	end
end

local function ensureWindow()
	if window then return window end

	window = CreateFrame("Frame", "HUI_MinimapButtonsWindow", UIParent, "BackdropTemplate")
	window:SetFrameStrata("DIALOG")
	if window.SetFrameLevel then window:SetFrameLevel(1000) end
	if window.SetToplevel then window:SetToplevel(true) end
	window:SetClampedToScreen(true)
	window:Hide()
	if window.GetFrameLevel then
		M._huiTooltipLevel = (window:GetFrameLevel() or 0) + 200
	end

	window:SetMovable(true)
	-- Don't let the window eat clicks; use a small drag handle instead.
	window:EnableMouse(false)

	-- Backdrop on a separate frame behind buttons (some buttons otherwise end up behind the backdrop).
	local bg = CreateFrame("Frame", nil, window, "BackdropTemplate")
	bg:SetAllPoints(window)
	-- Keep the backdrop reliably behind collected buttons.
	if bg.SetFrameStrata then bg:SetFrameStrata("LOW") end
	if bg.SetFrameLevel then bg:SetFrameLevel(1) end
	if bg.SetToplevel then bg:SetToplevel(false) end
	bg:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = EDGE_SIZE,
		insets = { left = EDGE_INSET, right = EDGE_INSET, top = EDGE_INSET, bottom = EDGE_INSET },
	})
	bg:SetBackdropColor(0, 0, 0, 0.8)
	window._huiBackdrop = bg

	local drag = CreateFrame("Frame", nil, window)
	drag:SetPoint("TOPLEFT", window, "TOPLEFT", EDGE_INSET, -EDGE_INSET)
	drag:SetPoint("TOPRIGHT", window, "TOPRIGHT", -EDGE_INSET, -EDGE_INSET)
	drag:SetHeight(HEADER_H)
	drag:EnableMouse(true)
	drag:RegisterForDrag("LeftButton")
	drag:SetScript("OnDragStart", function() window:StartMoving() end)
	drag:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
	window._huiDrag = drag

	container = CreateFrame("Frame", nil, window)
	if container.SetFrameStrata then container:SetFrameStrata("DIALOG") end
	if container.SetFrameLevel and window.GetFrameLevel then
		container:SetFrameLevel((window:GetFrameLevel() or 0) + 10)
	end
	container:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING, -(PADDING + HEADER_H))
	container:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PADDING, PADDING)

	window:SetScript("OnHide", function()
		-- Mimic MinimapButtonButton: keep buttons collected, just hide the container.
		container:Hide()
	end)

	return window
end

local function layoutButtons(buttons)
	local count = #buttons
	local cols = math.min(COLUMNS, math.max(1, count))
	local rows = math.ceil(count / cols)
	local width = (cols * BUTTON_SIZE) + ((cols - 1) * GAP) + (PADDING * 2)
	local height = (rows * BUTTON_SIZE) + ((rows - 1) * GAP) + (PADDING * 2) + HEADER_H

	window:SetSize(width, height)
	if not window._huiAnchored then
		window:SetPoint("TOP", Minimap, "BOTTOM", 0, -10)
		window._huiAnchored = true
	end

	for i = 1, count do
		local btn = buttons[i]
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		local orig = btn and btn._huiOrig
		if orig and orig.ClearAllPoints then
			orig.ClearAllPoints(btn)
		elseif btn.ClearAllPoints then
			btn:ClearAllPoints()
		end

		if orig and orig.SetPoint then
			orig.SetPoint(btn, "TOPLEFT", container, "TOPLEFT", col * (BUTTON_SIZE + GAP), -row * (BUTTON_SIZE + GAP))
		elseif btn.SetPoint then
			btn:SetPoint("TOPLEFT", container, "TOPLEFT", col * (BUTTON_SIZE + GAP), -row * (BUTTON_SIZE + GAP))
		end
	end
end

local function doNothing() end

-- Keep collected buttons as-is; forcing textures/alpha breaks some addons.

local function sortCollected()
	table.sort(collectedList, function(a, b)
		local an = a and a.GetName and a:GetName() or ""
		local bn = b and b.GetName and b:GetName() or ""
		return an < bn
	end)
end

local function rebuildLayout(force)
	if not window or (not force and not window:IsShown()) then return end

	local n = 0
	for i = 1, #collectedList do
		local btn = collectedList[i]
		if btn and btn.IsShown and btn:IsShown() then
			n = n + 1
			collectedVisible[n] = btn
		end
	end
	for i = n + 1, #collectedVisible do
		collectedVisible[i] = nil
	end

	layoutButtons(collectedVisible)
end

local function redockButton(btn)
	if not btn or not collected[btn] or not container then return end
	local p = btn.GetParent and btn:GetParent()
	if p ~= container then
		local orig = btn._huiOrig
		if orig and orig.SetParent then
			orig.SetParent(btn, container)
		elseif btn.SetParent then
			btn:SetParent(container)
		end
	end
	if btn.SetFrameStrata then btn:SetFrameStrata("DIALOG") end
	if btn.SetFrameLevel then
		local base = 0
		if container and container.GetFrameLevel then
			base = container:GetFrameLevel() or 0
		elseif window and window.GetFrameLevel then
			base = window:GetFrameLevel() or 0
		end
		btn:SetFrameLevel(base + 10)
	end
end

local function collectButton(btn)
	if collected[btn] then return end

	collected[btn] = true
	collectedList[#collectedList + 1] = btn
	btn._huiOrig = btn._huiOrig or {
		ClearAllPoints = btn.ClearAllPoints,
		SetPoint = btn.SetPoint,
		SetParent = btn.SetParent,
		SetScale = btn.SetScale,
	}

	if btn._huiOrig.SetParent then
		btn._huiOrig.SetParent(btn, container)
	elseif btn.SetParent then
		btn:SetParent(container)
	end
	-- Keep buttons above the container/backdrop without forcing extreme strata.
	if btn.SetFrameStrata then btn:SetFrameStrata(container:GetFrameStrata()) end
	if btn.SetFrameLevel and container and container.GetFrameLevel then
		btn:SetFrameLevel((container:GetFrameLevel() or 0) + 10)
	end
	if btn.SetIgnoreParentScale then btn:SetIgnoreParentScale(false) end
	if btn.SetScale then btn:SetScale(1) end
	if btn.SetScript then
		btn:SetScript("OnDragStart", nil)
		btn:SetScript("OnDragStop", nil)
	end

	-- Classic-era compatibility (MinimapButtonButton approach):
	-- Some addons constantly move their minimap buttons; block those calls.
	btn.ClearAllPoints = doNothing
	btn.SetPoint = doNothing
	btn.SetParent = doNothing
	btn.SetScale = doNothing

	if hooksecurefunc then
		hooksecurefunc(btn, "Show", rebuildLayout)
		hooksecurefunc(btn, "Hide", rebuildLayout)
	end
	if btn.HookScript then
		btn:HookScript("OnEnter", bringTooltipToFront)
	end
end

local function collectLibButtons()
	local lib = getLibDBIcon()
	if lib and lib.GetButtonList and lib.GetMinimapButton then
		for _, name in ipairs(lib:GetButtonList()) do
			local btn = lib:GetMinimapButton(name)
			if btn and isMinimapButton(btn) then collectButton(btn) end
		end
	end

	local map = getLibMapButton()
	if map and map.buttons then
		for _, btn in pairs(map.buttons) do
			if btn and isMinimapButton(btn) then collectButton(btn) end
		end
	end
end

local function collectAndDock()
	local prevCount = #collectedList

	collectLibButtons()

	for _, child in ipairs(getChildren(Minimap) or {}) do
		if isMinimapButton(child) then collectButton(child) end
	end

	if #collectedList > prevCount then
		sortCollected()
	end

	for i = 1, #collectedList do
		local btn = collectedList[i]
		if btn then
			local orig = btn._huiOrig
			if orig and orig.SetParent then
				orig.SetParent(btn, container)
			elseif btn.SetParent then
				btn:SetParent(container)
			end
		end
	end

	rebuildLayout(true)
end

local function toggleWindow()
	local w = ensureWindow()
	if w:IsShown() then
		if InCombatLockdown and InCombatLockdown() then
			pendingToggle = false
			w:Hide()
			return
		end
		w:Hide()
		return
	end

	if InCombatLockdown and InCombatLockdown() then
		pendingToggle = true
		return
	end

	container:Show()
	w:Show()
	collectAndDock()
end

local function ensureToggleButton()
	if toggleButton then return toggleButton end

	local parent = (Minimap and Minimap.GetParent and Minimap:GetParent()) or Minimap or UIParent
	toggleButton = CreateFrame("Button", "HUI_MinimapButtonsToggle", parent, "BackdropTemplate")
	toggleButton:SetSize(44, 44)
	if Minimap then
		toggleButton:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 0, 0)
	else
		toggleButton:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	toggleButton:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = EDGE_SIZE,
		insets = { left = EDGE_INSET, right = EDGE_INSET, top = EDGE_INSET, bottom = EDGE_INSET },
	})
	do
		local r, g, b = getPlayerColor()
		toggleButton:SetBackdropBorderColor(r, g, b, 1)
		toggleButton:SetBackdropColor(0, 0, 0, 0)
	end
	toggleButton:EnableMouse(true)
	if toggleButton.SetFrameStrata then toggleButton:SetFrameStrata("HIGH") end
	if toggleButton.SetFrameLevel and Minimap and Minimap.GetFrameLevel then
		toggleButton:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 200)
	end
	toggleButton:RegisterForClicks("LeftButtonUp")
	toggleButton:SetScript("OnClick", toggleWindow)

	local icon = toggleButton:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\AddOns\\HUI\\Media\\Logo.blp")
	icon:SetPoint("TOPLEFT", toggleButton, "TOPLEFT", EDGE_INSET, -EDGE_INSET)
	icon:SetPoint("BOTTOMRIGHT", toggleButton, "BOTTOMRIGHT", -EDGE_INSET, EDGE_INSET)
	icon:SetVertexColor(1, 1, 1, 1)
	icon:SetDrawLayer("BACKGROUND", -8)
	toggleButton._huiIcon = icon

	local hover = toggleButton:CreateTexture(nil, "HIGHLIGHT")
	hover:SetTexture("Interface\\Buttons\\WHITE8x8")
	hover:SetPoint("TOPLEFT", toggleButton, "TOPLEFT", EDGE_INSET, -EDGE_INSET)
	hover:SetPoint("BOTTOMRIGHT", toggleButton, "BOTTOMRIGHT", -EDGE_INSET, EDGE_INSET)
	hover:SetBlendMode("ADD")
	hover:SetVertexColor(1, 1, 1, 0)
	toggleButton._huiHover = hover

	local function setHoverAlpha(a)
		if toggleButton._huiHoverAlpha == a then return end
		toggleButton._huiHoverAlpha = a
		hover:SetVertexColor(1, 1, 1, a)
	end

	local function animateTo(target)
		if toggleButton._huiAnimTarget == target then return end
		toggleButton._huiAnimTarget = target
		toggleButton:SetScript("OnUpdate", function(self, elapsed)
			local cur = self._huiHoverAlpha or 0
			local speed = 24
			local next = cur + (target - cur) * math.min(elapsed * speed, 1)
			if math.abs(target - next) < 0.01 then
				next = target
				self:SetScript("OnUpdate", nil)
			end
			setHoverAlpha(next)
		end)
	end

	toggleButton:HookScript("OnEnter", function() animateTo(0.22) end)
	toggleButton:HookScript("OnLeave", function() animateTo(0) end)

	local hl = toggleButton:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture(nil)

	return toggleButton
end

local function ensureCombatHandler()
	if M._huiCombatHandler then return end
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
	f:SetScript("OnEvent", function()
		if pendingToggle == nil then return end
		local doOpen = pendingToggle
		pendingToggle = nil
		if doOpen then
			toggleWindow()
		else
			local w = ensureWindow()
			if w:IsShown() then w:Hide() end
		end
	end)
	M._huiCombatHandler = f
end

local function ensureCollectors()
	if M._huiCollectors then return end

	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_LOGIN")
	f:SetScript("OnEvent", function()
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				if container then collectAndDock() end
			end)
			C_Timer.After(1, function()
				if container then collectAndDock() end
			end)
		end

		local lib = getLibDBIcon()
		if lib and lib.RegisterCallback then
			pcall(lib.RegisterCallback, lib, ADDON_NAME, "LibDBIcon_IconCreated", function(_, btn)
				if container and btn and isMinimapButton(btn) then
					local prev = #collectedList
					collectButton(btn)
					if #collectedList > prev then
						sortCollected()
						rebuildLayout()
					end
				end
			end)
		end
	end)

	M._huiCollectors = f
end

function M:Apply(db)
	if db and db.enable and db.enable.minimap == false then return end
	if not Minimap then return end
	ensureToggleButton()
	ensureCombatHandler()
	ensureWindow()
	hookTooltip()
	ensureCollectors()
end

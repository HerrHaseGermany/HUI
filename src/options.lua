local ADDON_NAME, HUI = ...

local function makeHeader(parent, text, y)
	local h = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	h:SetPoint("TOPLEFT", 16, y)
	h:SetText(text)
	return h
end

local function makeLabel(parent, text, anchor, x, y)
	local l = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	l:SetPoint(anchor, x, y)
	l:SetText(text)
	return l
end

local function makeCheckbox(parent, label, anchor, x, y, onClick)
	local c = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
	c:SetPoint(anchor, x, y)
	c.Text:SetText(label)
	c:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
	return c
end

local function makeButton(parent, text, anchor, x, y, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetPoint(anchor, x, y)
	b:SetText(text)
	b:SetWidth(150)
	b:SetHeight(22)
	b:SetScript("OnClick", onClick)
	return b
end

local function makeSlider(parent, label, minV, maxV, step, anchor, x, y, onChange)
	local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
	s:SetPoint(anchor, x, y)
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	s:SetObeyStepOnDrag(true)
	s:SetWidth(280)
	if s.SetHeight then s:SetHeight(18) end

	if s.Low and s.High and s.Text then
		s.Low:SetText(tostring(minV))
		s.High:SetText(tostring(maxV))
		s.Text:SetText(label)
	end

	local function formatValue(v)
		if step and step < 1 then
			return string.format("%.2f", v)
		end
		return tostring(math.floor(v + 0.5))
	end

	local thumb = s.Thumb or (s.GetThumbTexture and s:GetThumbTexture())
	local overlay = CreateFrame("Frame", nil, s)
	overlay:SetFrameStrata("FULLSCREEN_DIALOG")
	overlay:SetFrameLevel((s:GetFrameLevel() or 0) + 50)
	overlay:SetSize(1, 1)
	if thumb then
		overlay:SetPoint("CENTER", thumb, "CENTER", 0, 0)
	else
		overlay:SetPoint("CENTER", s, "CENTER", 0, 0)
	end

	local thumbBg = overlay:CreateTexture(nil, "BACKGROUND")
	thumbBg:SetTexture("Interface\\Buttons\\WHITE8x8")
	thumbBg:SetVertexColor(0, 0, 0, 0.75)
	thumbBg:SetAllPoints(overlay)

	local thumbText = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	thumbText:SetPoint("CENTER", overlay, "CENTER", 0, 0)
	thumbText:SetText("")

	-- Keep thumb draggable but invisible.
	if s.SetThumbTexture and s.GetThumbTexture then
		local t = s:GetThumbTexture()
		if t and t.SetTexture and t.SetVertexColor then
			t:SetTexture("Interface\\Buttons\\WHITE8x8")
			t:SetVertexColor(0, 0, 0, 0)
		end
	end

	local inlineEdit = CreateFrame("EditBox", nil, overlay)
	inlineEdit:SetAutoFocus(false)
	inlineEdit:SetJustifyH("CENTER")
	if inlineEdit.SetFont then
		inlineEdit:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
	end
	if inlineEdit.SetTextInsets then
		inlineEdit:SetTextInsets(0, 0, 0, 0)
	end
	inlineEdit:SetTextColor(1, 1, 1, 1)
	inlineEdit:Hide()
	inlineEdit:SetFrameLevel((overlay:GetFrameLevel() or 0) + 2)

	local editBlocker = CreateFrame("Button", nil, s)
	editBlocker:SetAllPoints(s)
	editBlocker:Hide()
	editBlocker:SetFrameLevel((overlay:GetFrameLevel() or 0) + 1)
	editBlocker:RegisterForClicks("AnyUp")

	local function hideInlineEdit()
		inlineEdit:ClearFocus()
		inlineEdit:SetScript("OnUpdate", nil)
		inlineEdit:Hide()
		editBlocker:Hide()
		thumbBg:Show()
		thumbText:Show()
	end

	editBlocker:SetScript("OnClick", function()
		if inlineEdit and inlineEdit:IsShown() then
			inlineEdit:ClearFocus()
		end
	end)

	local function showInlineEdit()
		inlineEdit:ClearAllPoints()
		inlineEdit:SetAllPoints(overlay)
		local w, h = overlay:GetSize()
		if w and h then
			inlineEdit:SetSize(math.max(24, w), math.max(18, h))
		end
		inlineEdit:SetText(formatValue(s:GetValue()))
		inlineEdit:HighlightText()
		thumbText:Hide()
		thumbBg:Hide()
		editBlocker:Show()
		inlineEdit:Show()
		inlineEdit:SetEnabled(true)
		inlineEdit:SetAlpha(1)
		inlineEdit:SetTextColor(1, 1, 1, 1)
		inlineEdit:SetScript("OnUpdate", function(self)
			self:SetTextColor(1, 1, 1, 1)
			self:SetAlpha(1)
		end)
		inlineEdit:SetFocus()
	end

	inlineEdit:SetScript("OnEscapePressed", hideInlineEdit)
	inlineEdit:SetScript("OnEditFocusLost", hideInlineEdit)
	inlineEdit:SetScript("OnEnterPressed", function(self)
		local v = tonumber(self:GetText())
		if v then
			s._huiLock = true
			s:SetValue(v)
			s._huiLock = nil
			onChange(v)
		end
		hideInlineEdit()
	end)

	function s:_huiUpdateValueText(v)
		thumbText:SetText(formatValue(v))
		local w = (thumbText.GetStringWidth and thumbText:GetStringWidth()) or 0
		local h = (thumbText.GetStringHeight and thumbText:GetStringHeight()) or 0
		if w <= 0 then w = 24 end
		if h <= 0 then h = 12 end
		overlay:SetSize(w + 10, h + 6)
	end

	function s:_huiDeferValueTextRefresh()
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				if s and s._huiUpdateValueText then
					s:_huiUpdateValueText(s:GetValue())
				end
			end)
		end
	end

	s:SetScript("OnValueChanged", function(self, value)
		if self._huiLock then return end
		self:_huiUpdateValueText(value)
		onChange(value)
	end)

	s:SetScript("OnMouseDown", function(_, button)
		if button == "RightButton" then
			s._huiRightClickValue = s:GetValue()
		end
	end)
	s:SetScript("OnMouseUp", function(_, button)
		if button ~= "RightButton" then return end
		if s._huiRightClickValue ~= nil then
			s._huiLock = true
			s:SetValue(s._huiRightClickValue)
			s._huiLock = nil
			s._huiRightClickValue = nil
		end
		showInlineEdit()
	end)

	s:_huiUpdateValueText(s:GetValue())
	s:_huiDeferValueTextRefresh()
	return s
end

local function resetDB()
	HUIDB = nil
	HUI:GetDB()
	HUI:ApplyAll()
end

local function createTabFrame()
	local f = CreateFrame("Frame", "HUI_ConfigFrame", UIParent, "BackdropTemplate")
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetToplevel(true)
	-- Allow dragging partially off-screen for better placement.
	f:SetClampedToScreen(false)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:EnableKeyboard(true)
	f:SetSize(820, 680)
	f:SetPoint("CENTER")
	f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	f:SetBackdropColor(0.10, 0.10, 0.10, 0.95)
	f:SetBackdropBorderColor(0, 0, 0, 1)
	f:Hide()
	tinsert(UISpecialFrames, f:GetName())

	local dragBar = CreateFrame("Button", nil, f)
	dragBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	-- Leave space on the right for the Close button so drag capture doesn't interfere.
	dragBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -84, 0)
	dragBar:SetHeight(34)
	dragBar:EnableMouse(true)
	dragBar:RegisterForDrag("LeftButton")
	dragBar:SetScript("OnDragStart", function() f:StartMoving() end)
	dragBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 12, -10)
	title:SetText("HUI")

	local function closeWindow()
		f:Hide()
	end

	local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -8)
	closeBtn:SetSize(60, 20)
	closeBtn:SetText("Close")
	closeBtn:SetFrameLevel((dragBar:GetFrameLevel() or 0) + 5)
	closeBtn:SetScript("OnClick", closeWindow)

	f:SetScript("OnHide", function() end)
	f:SetScript("OnKeyDown", function(_, key)
		if key == "ESCAPE" then
			closeWindow()
		end
	end)

	f._huiTabs = {}
	f._huiPages = {}

	local function addPage(key, text)
		local idx = #f._huiTabs + 1
		local tab = CreateFrame("Button", f:GetName() .. "Tab" .. idx, f, "OptionsFrameTabButtonTemplate")
		tab:SetID(idx)
		tab:SetText(text)
		tab:SetScript("OnClick", function(self)
			PanelTemplates_SetTab(f, self:GetID())
			for i, page in ipairs(f._huiPages) do
				page:SetShown(i == self:GetID())
			end
		end)
		if idx == 1 then
			tab:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -34)
		else
			tab:SetPoint("LEFT", f._huiTabs[idx - 1], "RIGHT", -14, 0)
		end
		PanelTemplates_TabResize(tab, 0)
		f._huiTabs[idx] = tab

		local page = CreateFrame("Frame", nil, f)
		page:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -62)
		page:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
		page:Hide()

		local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
		scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -30, 0)
		local root = CreateFrame("Frame", nil, scroll)
		root:SetSize(780, 1600)
		scroll:SetScrollChild(root)
		scroll:SetScript("OnSizeChanged", function(_, w)
			if not w or w <= 0 then return end
			root:SetWidth(math.max(780, w))
		end)

		page._huiRoot = root
		f._huiPages[idx] = page
		f._huiPagesByKey = f._huiPagesByKey or {}
		f._huiPagesByKey[key] = page
	end

	addPage("general", "General")
	addPage("unitframes", "Unitframes")
	addPage("chat", "Chat")
	addPage("bars", "Bars")
	addPage("micromenu", "Micromenu")

	PanelTemplates_SetNumTabs(f, #f._huiTabs)
	PanelTemplates_SetTab(f, 1)
	f._huiPages[1]:Show()
	return f
end

local config = createTabFrame()

config._huiControls = config._huiControls or {}

local function bindSlider(root, pathName, key, label, minV, maxV, step, anchor, x, y)
	return makeSlider(root, label, minV, maxV, step, anchor, x, y, function(v)
		local db = HUI:GetDB()
		db[pathName] = db[pathName] or {}
		db[pathName][key] = v
		HUI:ApplyAll()
	end)
end

local function buildUI()
	-- General
	do
		local root = config._huiPagesByKey.general._huiRoot
		makeHeader(root, "General", -16)
		config._huiControls.unlockMovers = makeCheckbox(root, "Unlock movers (drag elements with mouse)", "TOPLEFT", 16, -44, function(v)
			local db = HUI:GetDB()
			db.moversUnlocked = v
			config._huiControls.unlockMovers:SetChecked(v and true or false)
			HUI:ApplyAll()
		end)
		makeButton(root, "Reset to Defaults", "TOPLEFT", 16, -78, resetDB)
		makeButton(root, "Reload UI", "TOPLEFT", 180, -78, ReloadUI)
		makeHeader(root, "Scale", -124)
		makeSlider(root, "UI Scale", 0.70, 1.30, 0.01, "TOPLEFT", 16, -152, function(v)
			local db = HUI:GetDB()
			db.scale = v
			HUI:ApplyAll()
		end)
	end

	-- Unitframes
	do
		local root = config._huiPagesByKey.unitframes._huiRoot
		config._huiControls.enableUnitframes = makeCheckbox(root, "Enable custom Unitframes", "TOPLEFT", 16, -16, function(v)
			local db = HUI:GetDB()
			db.enable = db.enable or {}
			db.enable.unitframes = v and true or false
			config._huiControls.enableUnitframes:SetChecked(v and true or false)
			HUI:ApplyAll()
		end)
		makeHeader(root, "Unitframes", -52)
		makeLabel(root, "Currently: options only. We'll add the new unitframes module next.", "TOPLEFT", 16, -84)
	end

	-- Chat
	do
		local root = config._huiPagesByKey.chat._huiRoot
		config._huiControls.enableChat = makeCheckbox(root, "Enable custom Chat", "TOPLEFT", 16, -16, function(v)
			local db = HUI:GetDB()
			db.enable = db.enable or {}
			db.enable.chat = v
			config._huiControls.enableChat:SetChecked(v and true or false)
			HUI:ApplyAll()
		end)
		makeHeader(root, "ChatFrame1", -52)
		bindSlider(root, "chat", "x", "X", 0, 800, 1, "TOPLEFT", 16, -80)
		bindSlider(root, "chat", "y", "Y", 0, 600, 1, "TOPLEFT", 320, -80)
		bindSlider(root, "chat", "w", "Width", 200, 900, 1, "TOPLEFT", 16, -120)
		bindSlider(root, "chat", "h", "Height", 100, 700, 1, "TOPLEFT", 320, -120)
	end

	-- Bars
	do
		local root = config._huiPagesByKey.bars._huiRoot
		config._huiControls.enableActionbars = makeCheckbox(root, "Enable custom Actionbars", "TOPLEFT", 16, -16, function(v)
			local db = HUI:GetDB()
			db.enable = db.enable or {}
			db.enable.actionbars = v
			config._huiControls.enableActionbars:SetChecked(v and true or false)
			HUI:ApplyAll()
		end)
		makeHeader(root, "Actionbars", -52)
		bindSlider(root, "actionbars", "x", "X", -800, 800, 1, "TOPLEFT", 16, -80)
		bindSlider(root, "actionbars", "y", "Y", 0, 300, 1, "TOPLEFT", 320, -80)
		makeSlider(root, "Scale", 0.70, 1.30, 0.01, "TOPLEFT", 16, -120, function(v)
			local db = HUI:GetDB()
			db.actionbars = db.actionbars or {}
			db.actionbars.scale = v
			HUI:ApplyAll()
		end)
	end

	-- Micromenu
	do
		local root = config._huiPagesByKey.micromenu._huiRoot
		config._huiControls.enableMicromenu = makeCheckbox(root, "Enable custom Micromenu", "TOPLEFT", 16, -16, function(v)
			local db = HUI:GetDB()
			db.enable = db.enable or {}
			db.enable.micromenu = v
			config._huiControls.enableMicromenu:SetChecked(v and true or false)
			HUI:ApplyAll()
		end)
		makeHeader(root, "Micromenu", -52)
		bindSlider(root, "micromenu", "x", "X", -800, 800, 1, "TOPLEFT", 16, -80)
		bindSlider(root, "micromenu", "y", "Y", 0, 200, 1, "TOPLEFT", 320, -80)
		makeSlider(root, "Scale", 0.70, 1.30, 0.01, "TOPLEFT", 16, -120, function(v)
			local db = HUI:GetDB()
			db.micromenu = db.micromenu or {}
			db.micromenu.scale = v
			HUI:ApplyAll()
		end)
	end
end

buildUI()

		local function refreshAll()
			local db = HUI:GetDB()
			db.enable = db.enable or {}
		if db.enable.unitframes == nil then db.enable.unitframes = false end
		if db.enable.actionbars == nil then db.enable.actionbars = true end
		if db.enable.chat == nil then db.enable.chat = true end
		if db.enable.micromenu == nil then db.enable.micromenu = true end

		if config._huiControls.unlockMovers then
			config._huiControls.unlockMovers:SetChecked(db.moversUnlocked and true or false)
		end
		if config._huiControls.enableUnitframes then
			config._huiControls.enableUnitframes:SetChecked(db.enable.unitframes and true or false)
		end
		if config._huiControls.enableActionbars then
			config._huiControls.enableActionbars:SetChecked(db.enable.actionbars and true or false)
		end
	if config._huiControls.enableChat then
		config._huiControls.enableChat:SetChecked(db.enable.chat and true or false)
	end
	if config._huiControls.enableMicromenu then
		config._huiControls.enableMicromenu:SetChecked(db.enable.micromenu and true or false)
	end

	-- General
	-- (no direct refs; sliders update on open)
end

	function HUI:OpenOptions()
		if not config then return end
		config:ClearAllPoints()
		config:SetPoint("CENTER")
		config:Show()
		refreshAll()
		-- Ensure the UI reflects current settings immediately (e.g. dummy bars)
		HUI:ApplyAll()
	end

	-- Close on entering combat.
	do
		local f = CreateFrame("Frame")
		f:RegisterEvent("PLAYER_REGEN_DISABLED")
		f:SetScript("OnEvent", function()
			if config and config.IsShown and config:IsShown() then
				config:Hide()
			end
		end)
	end

SLASH_HUI1 = "/hui"
SlashCmdList.HUI = function()
	HUI:OpenOptions()
end

-- ESC menu button
local function ensureGameMenuButton()
	if not GameMenuFrame or _G.GameMenuButtonHUI then return end
	local b = CreateFrame("Button", "GameMenuButtonHUI", GameMenuFrame, "GameMenuButtonTemplate")
	b:SetText("HUI")
	b:SetScript("OnClick", function()
		if HideUIPanel then HideUIPanel(GameMenuFrame) else GameMenuFrame:Hide() end
		HUI:OpenOptions()
	end)

	b:SetSize(144, 21)
end

local function layoutGameMenuButtons()
	if not GameMenuFrame or not _G.GameMenuButtonHUI then return end
	local hui = _G.GameMenuButtonHUI
	local options = _G.GameMenuButtonOptions
	if not options then return end

	-- Gather all shown buttons in the menu.
	local buttons = {}
	for _, child in ipairs({ GameMenuFrame:GetChildren() }) do
		if type(child) == "table" and child.IsShown and child:IsShown() and child.GetName then
			local name = child:GetName()
			if name and name:match("^GameMenuButton") then
				buttons[#buttons + 1] = child
			end
		end
	end

	-- Ensure our button participates even if hidden earlier.
	local found = false
	for _, btn in ipairs(buttons) do
		if btn == hui then found = true break end
	end
	if not found then buttons[#buttons + 1] = hui end
	hui:Show()

	-- Sort by current top position so we preserve existing ordering (including other addons),
	-- then inject HUI directly after Options.
	table.sort(buttons, function(a, b)
		local at = a.GetTop and a:GetTop() or 0
		local bt = b.GetTop and b:GetTop() or 0
		if at == bt then
			return (a:GetName() or "") < (b:GetName() or "")
		end
		return at > bt
	end)

	-- Remove HUI if already in list.
	for i = #buttons, 1, -1 do
		if buttons[i] == hui then table.remove(buttons, i) end
	end

	-- Insert HUI at the Options position (swap), then put Options after HUI.
	local inserted = false
	for i = 1, #buttons do
		if buttons[i] == options then
			table.insert(buttons, i, hui)
			table.remove(buttons, i + 1) -- remove the original options at i+1 (shifted)
			table.insert(buttons, i + 1, options)
			inserted = true
			break
		end
	end
	if not inserted then
		buttons[#buttons + 1] = hui
	end

	-- Use the current top-most button's anchor as the start, then stack everything below it.
	local first = buttons[1]
	if not first or not first.GetPoint then return end
	local p, rel, rp, x, y = first:GetPoint(1)
	rel = rel or GameMenuFrame
	p = p or "TOP"
	rp = rp or "TOP"
	x = x or 0
	y = y or -60

	first:ClearAllPoints()
	first:SetPoint(p, rel, rp, x, y)

	local function gapAfter(btn)
		local name = btn.GetName and btn:GetName() or ""
		-- Extra gap after Support/Help and after AddOns (before Logout section).
		if name == "GameMenuButtonSupport" or name == "GameMenuButtonHelp" then return -20 end
		if name == "GameMenuButtonAddons" then return -20 end
		return -1
	end

	for i = 2, #buttons do
		local btn = buttons[i]
		btn:ClearAllPoints()
		btn:SetPoint("TOP", buttons[i - 1], "BOTTOM", 0, gapAfter(buttons[i - 1]))
	end

	-- Expand the menu if needed.
	if GameMenuFrame.SetHeight and buttons[#buttons].GetBottom and buttons[1].GetTop then
		local top = buttons[1]:GetTop() or 0
		local bottom = buttons[#buttons]:GetBottom() or 0
		if top > 0 and bottom > 0 then
			local desired = (top - bottom) + 70
			if desired > GameMenuFrame:GetHeight() then
				GameMenuFrame:SetHeight(desired)
			end
		end
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	ensureGameMenuButton()
	if GameMenuFrame and GameMenuFrame.HookScript then
		GameMenuFrame:HookScript("OnShow", layoutGameMenuButtons)
	end
	if hooksecurefunc and _G.GameMenuFrame_UpdateVisibleButtons then
		hooksecurefunc("GameMenuFrame_UpdateVisibleButtons", layoutGameMenuButtons)
	end
	layoutGameMenuButtons()
end)

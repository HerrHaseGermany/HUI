local ADDON_NAME, HUI = ...

local function numOrNil(text)
	local n = tonumber(text)
	if not n then return nil end
	if n ~= n or n == math.huge or n == -math.huge then return nil end
	return n
end

local function setNum(pathTable, key, value)
	if value == nil then return end
	pathTable[key] = value
end

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

local function makeSlider(parent, label, minV, maxV, step, anchor, x, y, onChange)
	local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
	s:SetPoint(anchor, x, y)
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	s:SetObeyStepOnDrag(true)
	s:SetWidth(260)

	_G[s:GetName() .. "Low"]:SetText(tostring(minV))
	_G[s:GetName() .. "High"]:SetText(tostring(maxV))
	_G[s:GetName() .. "Text"]:SetText(label)

	s:SetScript("OnValueChanged", function(self, value)
		if self._huiLock then return end
		onChange(value)
	end)
	return s
end

local function makeEdit(parent, width, anchor, x, y, onEnter)
	local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	e:SetPoint(anchor, x, y)
	e:SetWidth(width)
	e:SetHeight(20)
	e:SetAutoFocus(false)
	e:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		onEnter(self:GetText())
	end)
	return e
end

local function makeButton(parent, text, anchor, x, y, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetPoint(anchor, x, y)
	b:SetText(text)
	b:SetWidth(120)
	b:SetHeight(22)
	b:SetScript("OnClick", onClick)
	return b
end

local function resetDB()
	HUIDB = nil
	HUI:GetDB()
	HUI:ApplyAll()
end

local function openPanel(panel)
	if InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(panel)
		InterfaceOptionsFrame_OpenToCategory(panel)
	end
end

local panel = CreateFrame("Frame", "HUI_OptionsPanel", UIParent)
panel.name = "HUI"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("HUI")

local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
sub:SetText("Edit positions, sizes, and scales. Some secure elements update after leaving combat.")

makeHeader(panel, "Global", -56)

local db

local function ensureEnable()
	db.enable = db.enable or {}
	if db.enable.unitframes == nil then db.enable.unitframes = true end
	if db.enable.actionbars == nil then db.enable.actionbars = true end
	if db.enable.minimap == nil then db.enable.minimap = true end
	if db.enable.chat == nil then db.enable.chat = true end
	if db.enable.micromenu == nil then db.enable.micromenu = true end
end

local function makeCheckbox(parent, label, anchor, x, y, onClick)
	local c = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
	c:SetPoint(anchor, x, y)
	c.Text:SetText(label)
	c:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
	return c
end

local enableUnitframes = makeCheckbox(panel, "Custom Unitframes", "TOPLEFT", 16, -84, function(v)
	ensureEnable()
	db.enable.unitframes = v
	HUI:ApplyAll()
end)

local enableActionbars = makeCheckbox(panel, "Custom Actionbars", "TOPLEFT", 200, -84, function(v)
	ensureEnable()
	db.enable.actionbars = v
	HUI:ApplyAll()
end)

local enableMinimap = makeCheckbox(panel, "Custom Minimap", "TOPLEFT", 16, -110, function(v)
	ensureEnable()
	db.enable.minimap = v
	HUI:ApplyAll()
end)

local enableChat = makeCheckbox(panel, "Custom Chat", "TOPLEFT", 200, -110, function(v)
	ensureEnable()
	db.enable.chat = v
	HUI:ApplyAll()
end)

local enableMicromenu = makeCheckbox(panel, "Custom Micromenu", "TOPLEFT", 16, -136, function(v)
	ensureEnable()
	db.enable.micromenu = v
	HUI:ApplyAll()
end)

local scaleSlider = makeSlider(panel, "UI Scale", 0.70, 1.30, 0.01, "TOPLEFT", 16, -86, function(v)
	db.scale = v
	HUI:ApplyAll()
end)

scaleSlider:ClearAllPoints()
scaleSlider:SetPoint("TOPLEFT", 16, -174)

makeHeader(panel, "Unitframes", -220)

makeLabel(panel, "Player (x, y, w, h)", "TOPLEFT", 16, -250)
local pX = makeEdit(panel, 50, "TOPLEFT", 180, -248, function(t) setNum(db.player, "x", numOrNil(t)); HUI:ApplyAll() end)
local pY = makeEdit(panel, 50, "TOPLEFT", 238, -248, function(t) setNum(db.player, "y", numOrNil(t)); HUI:ApplyAll() end)
local pW = makeEdit(panel, 50, "TOPLEFT", 296, -248, function(t) setNum(db.player, "w", numOrNil(t)); HUI:ApplyAll() end)
local pH = makeEdit(panel, 50, "TOPLEFT", 354, -248, function(t) setNum(db.player, "h", numOrNil(t)); HUI:ApplyAll() end)

makeLabel(panel, "Target (x, y, w, h)", "TOPLEFT", 16, -278)
local tX = makeEdit(panel, 50, "TOPLEFT", 180, -276, function(t) setNum(db.target, "x", numOrNil(t)); HUI:ApplyAll() end)
local tY = makeEdit(panel, 50, "TOPLEFT", 238, -276, function(t) setNum(db.target, "y", numOrNil(t)); HUI:ApplyAll() end)
local tW = makeEdit(panel, 50, "TOPLEFT", 296, -276, function(t) setNum(db.target, "w", numOrNil(t)); HUI:ApplyAll() end)
local tH = makeEdit(panel, 50, "TOPLEFT", 354, -276, function(t) setNum(db.target, "h", numOrNil(t)); HUI:ApplyAll() end)

makeLabel(panel, "TargetTarget (x, y, w, h)", "TOPLEFT", 16, -306)
local ttX = makeEdit(panel, 50, "TOPLEFT", 180, -304, function(t) setNum(db.targettarget, "x", numOrNil(t)); HUI:ApplyAll() end)
local ttY = makeEdit(panel, 50, "TOPLEFT", 238, -304, function(t) setNum(db.targettarget, "y", numOrNil(t)); HUI:ApplyAll() end)
local ttW = makeEdit(panel, 50, "TOPLEFT", 296, -304, function(t) setNum(db.targettarget, "w", numOrNil(t)); HUI:ApplyAll() end)
local ttH = makeEdit(panel, 50, "TOPLEFT", 354, -304, function(t) setNum(db.targettarget, "h", numOrNil(t)); HUI:ApplyAll() end)

makeHeader(panel, "Minimap", -350)
makeLabel(panel, "x, y, size", "TOPLEFT", 16, -380)
local mmX = makeEdit(panel, 60, "TOPLEFT", 100, -378, function(t) setNum(db.minimap, "x", numOrNil(t)); HUI:ApplyAll() end)
local mmY = makeEdit(panel, 60, "TOPLEFT", 166, -378, function(t) setNum(db.minimap, "y", numOrNil(t)); HUI:ApplyAll() end)
local mmS = makeEdit(panel, 60, "TOPLEFT", 232, -378, function(t) setNum(db.minimap, "size", numOrNil(t)); HUI:ApplyAll() end)

makeHeader(panel, "Chat", -420)
makeLabel(panel, "x, y, w, h", "TOPLEFT", 16, -450)
local cX = makeEdit(panel, 60, "TOPLEFT", 100, -448, function(t) setNum(db.chat, "x", numOrNil(t)); HUI:ApplyAll() end)
local cY = makeEdit(panel, 60, "TOPLEFT", 166, -448, function(t) setNum(db.chat, "y", numOrNil(t)); HUI:ApplyAll() end)
local cW = makeEdit(panel, 60, "TOPLEFT", 232, -448, function(t) setNum(db.chat, "w", numOrNil(t)); HUI:ApplyAll() end)
local cH = makeEdit(panel, 60, "TOPLEFT", 298, -448, function(t) setNum(db.chat, "h", numOrNil(t)); HUI:ApplyAll() end)

makeHeader(panel, "Bars", -490)
makeLabel(panel, "Actionbars (x, y, scale)", "TOPLEFT", 16, -520)
local abX = makeEdit(panel, 60, "TOPLEFT", 180, -518, function(t) setNum(db.actionbars, "x", numOrNil(t)); HUI:ApplyAll() end)
local abY = makeEdit(panel, 60, "TOPLEFT", 246, -518, function(t) setNum(db.actionbars, "y", numOrNil(t)); HUI:ApplyAll() end)
local abS = makeEdit(panel, 60, "TOPLEFT", 312, -518, function(t) setNum(db.actionbars, "scale", numOrNil(t)); HUI:ApplyAll() end)

makeLabel(panel, "Micromenu (x, y, scale)", "TOPLEFT", 16, -548)
local miX = makeEdit(panel, 60, "TOPLEFT", 180, -546, function(t) setNum(db.micromenu, "x", numOrNil(t)); HUI:ApplyAll() end)
local miY = makeEdit(panel, 60, "TOPLEFT", 246, -546, function(t) setNum(db.micromenu, "y", numOrNil(t)); HUI:ApplyAll() end)
local miS = makeEdit(panel, 60, "TOPLEFT", 312, -546, function(t) setNum(db.micromenu, "scale", numOrNil(t)); HUI:ApplyAll() end)

makeButton(panel, "Reset to Defaults", "TOPLEFT", 16, -600, function()
	resetDB()
	panel:refresh()
end)

makeButton(panel, "Reload UI", "TOPLEFT", 150, -600, function()
	ReloadUI()
end)

function panel:refresh()
	db = HUI:GetDB()
	ensureEnable()

	enableUnitframes:SetChecked(db.enable.unitframes and true or false)
	enableActionbars:SetChecked(db.enable.actionbars and true or false)
	enableMinimap:SetChecked(db.enable.minimap and true or false)
	enableChat:SetChecked(db.enable.chat and true or false)
	enableMicromenu:SetChecked(db.enable.micromenu and true or false)

	scaleSlider._huiLock = true
	scaleSlider:SetValue(db.scale or 1)
	scaleSlider._huiLock = nil

	pX:SetText(tostring(db.player.x)); pY:SetText(tostring(db.player.y)); pW:SetText(tostring(db.player.w)); pH:SetText(tostring(db.player.h))
	tX:SetText(tostring(db.target.x)); tY:SetText(tostring(db.target.y)); tW:SetText(tostring(db.target.w)); tH:SetText(tostring(db.target.h))
	ttX:SetText(tostring(db.targettarget.x)); ttY:SetText(tostring(db.targettarget.y)); ttW:SetText(tostring(db.targettarget.w)); ttH:SetText(tostring(db.targettarget.h))

	mmX:SetText(tostring(db.minimap.x)); mmY:SetText(tostring(db.minimap.y)); mmS:SetText(tostring(db.minimap.size))
	cX:SetText(tostring(db.chat.x)); cY:SetText(tostring(db.chat.y)); cW:SetText(tostring(db.chat.w)); cH:SetText(tostring(db.chat.h))
	abX:SetText(tostring(db.actionbars.x)); abY:SetText(tostring(db.actionbars.y)); abS:SetText(tostring(db.actionbars.scale))
	miX:SetText(tostring(db.micromenu.x)); miY:SetText(tostring(db.micromenu.y)); miS:SetText(tostring(db.micromenu.scale))
end

panel:SetScript("OnShow", function(self) self:refresh() end)

InterfaceOptions_AddCategory(panel)

SLASH_HUI1 = "/hui"
SlashCmdList.HUI = function(msg)
	msg = (msg or ""):lower()
	if msg == "reset" then
		resetDB()
		return
	end
	openPanel(panel)
end

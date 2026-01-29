local ADDON_NAME, HUI = ...

local M = { name = "actionbarsetup" }
table.insert(HUI.modules, M)

local ACTION_SLOTS = 120

local function playerGUID()
	return UnitGUID and UnitGUID("player") or nil
end

local function getProfiles(db)
	db.actionbarSetup = db.actionbarSetup or {}
	db.actionbarSetup.profiles = db.actionbarSetup.profiles or {}
	return db.actionbarSetup.profiles
end

local function findProfileGUIDByNameRealm(profiles, nameRealm)
	if not nameRealm or nameRealm == "" then return nil end
	nameRealm = nameRealm:lower()
	for guid, p in pairs(profiles) do
		local m = p and p.meta
		if m and m.name and m.realm then
			local key = (m.name .. "-" .. m.realm):lower()
			if key == nameRealm then return guid end
		end
	end
	return nil
end

local function buildMeta()
	local name = UnitName and UnitName("player") or "Unknown"
	local realm = GetRealmName and GetRealmName() or "Unknown"
	local className, classFile = "UNKNOWN", "UNKNOWN"
	if UnitClass then
		className, classFile = UnitClass("player")
	end

	return {
		guid = playerGUID(),
		name = name,
		realm = realm,
		class = classFile or className or "UNKNOWN",
	}
end

local function packAction(slot)
	local actionType, id, subType = GetActionInfo(slot)
	if not actionType then return nil end
	if actionType == "macro" then
		local macroName = GetMacroInfo and GetMacroInfo(id) or nil
		return { t = "macro", id = id, name = macroName }
	end
	if actionType == "spell" then
		return { t = "spell", id = id, sub = subType }
	end
	if actionType == "item" then
		return { t = "item", id = id }
	end
	return { t = actionType, id = id, sub = subType }
end

local function saveBarsToProfile(profile)
	profile.bars = profile.bars or {}
	local bars = profile.bars

	for slot = 1, ACTION_SLOTS do
		bars[slot] = packAction(slot)
	end
end

local function resolveMacroPickup(action)
	if not action then return false end
	if action.name and type(action.name) == "string" and action.name ~= "" and PickupMacro then
		PickupMacro(action.name)
		return true
	end
	if action.id and PickupMacro then
		PickupMacro(action.id)
		return true
	end
	return false
end

local function pickupForAction(action)
	if not action or not action.t then return false end
	if action.t == "spell" and PickupSpell then
		PickupSpell(action.id)
		return true
	end
	if action.t == "item" and PickupItem then
		PickupItem(action.id)
		return true
	end
	if action.t == "macro" then
		return resolveMacroPickup(action)
	end
	if action.t == "companion" and PickupCompanion then
		PickupCompanion(action.sub, action.id)
		return true
	end
	if action.t == "flyout" and PickupFlyout then
		PickupFlyout(action.id)
		return true
	end
	if action.t == "equipmentset" and PickupEquipmentSetByName and action.name then
		PickupEquipmentSetByName(action.name)
		return true
	end
	return false
end

function M:SaveCurrent()
	local db = HUI:GetDB()
	local profiles = getProfiles(db)
	local guid = playerGUID()
	if not guid then return false, "Player GUID not available yet." end

	local profile = profiles[guid] or {}
	profiles[guid] = profile

	profile.meta = buildMeta()
	profile.meta.lastSaved = time and time() or nil
	saveBarsToProfile(profile)

	return true
end

function M:LoadProfile(guid)
	if InCombatLockdown and InCombatLockdown() then
		return false, "Cannot load action bars in combat."
	end

	local db = HUI:GetDB()
	local profiles = getProfiles(db)
	local profile = guid and profiles[guid] or nil
	if not profile or not profile.bars then return false, "No saved action bars for that character." end

	local bars = profile.bars
	for slot = 1, ACTION_SLOTS do
		ClearCursor()
		PickupAction(slot)
		ClearCursor()

		local action = bars[slot]
		if action then
			ClearCursor()
			if pickupForAction(action) then
				PlaceAction(slot)
			else
				ClearCursor()
			end
		end
	end
	ClearCursor()
	return true
end

local function formatProfileLabel(profile)
	if not profile or not profile.meta then return "Unknown" end
	local m = profile.meta
	return string.format("%s-%s (%s)", m.name or "?", m.realm or "?", m.class or "?")
end

local function openOptionsUI()
	if Settings and Settings.OpenToCategory and M._settingsCategory then
		Settings.OpenToCategory(M._settingsCategory:GetID())
		return true
	end
	if InterfaceOptionsFrame_OpenToCategory and M._interfaceCategoryName then
		InterfaceOptionsFrame_OpenToCategory(M._interfaceCategoryName)
		InterfaceOptionsFrame_OpenToCategory(M._interfaceCategoryName)
		return true
	end
	return false
end

local function ensureOptions()
	if M._optionsBuilt then return end
	M._optionsBuilt = true

	local function addTitle(panel, text)
		local t = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		t:SetPoint("TOPLEFT", 16, -16)
		t:SetText(text)
		return t
	end

	local function addText(panel, anchor, text)
		local f = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
		f:SetJustifyH("LEFT")
		f:SetText(text)
		return f
	end

	local root = CreateFrame("Frame", "HUIOptionsPanel", UIParent)
	root.name = "HUI"
	addTitle(root, "HUI")
	addText(root, root, "Options live in subcategories.")

	local panel = CreateFrame("Frame", "HUIOptionsActionbarsPanel", UIParent)
	panel.name = "Actionbars"
	panel.parent = "HUI"

	local title = addTitle(panel, "HUI - Actionbars")
	local help = addText(panel, title, "Save action bar buttons per character (GUID) and load them later.")

	local status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	status:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -10)
	status:SetJustifyH("LEFT")
	status:SetText("")

	local dropdown = CreateFrame("Frame", "HUIActionbarSetupProfileDropdown", panel, "UIDropDownMenuTemplate")
	dropdown:SetPoint("TOPLEFT", status, "BOTTOMLEFT", -14, -6)

	local selectedGUID

	local function refreshStatus()
		local db = HUI:GetDB()
		local profiles = getProfiles(db)
		local p = selectedGUID and profiles[selectedGUID] or nil
		if p and p.meta then
			local when = p.meta.lastSaved and date and date("%Y-%m-%d %H:%M:%S", p.meta.lastSaved) or "unknown"
			status:SetText("Selected: " .. formatProfileLabel(p) .. " | Last saved: " .. when)
		else
			status:SetText("Selected: (none)")
		end
	end

	local function getSortedProfileGUIDs()
		local db = HUI:GetDB()
		local profiles = getProfiles(db)
		local guids = {}
		for guid in pairs(profiles) do
			guids[#guids + 1] = guid
		end
		table.sort(guids, function(a, b)
			return formatProfileLabel(profiles[a]) < formatProfileLabel(profiles[b])
		end)
		return guids, profiles
	end

	local function selectGUID(guid)
		selectedGUID = guid
		local db = HUI:GetDB()
		local profiles = getProfiles(db)
		local label = guid and profiles[guid] and formatProfileLabel(profiles[guid]) or "(none)"
		UIDropDownMenu_SetText(dropdown, label)
		refreshStatus()
	end

	UIDropDownMenu_SetWidth(dropdown, 240)
	UIDropDownMenu_Initialize(dropdown, function(self, level)
		local guids, profiles = getSortedProfileGUIDs()
		for _, guid in ipairs(guids) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = formatProfileLabel(profiles[guid])
			info.func = function() selectGUID(guid) end
			info.checked = (guid == selectedGUID)
			UIDropDownMenu_AddButton(info, level)
		end
	end)

	local saveBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	saveBtn:SetSize(140, 22)
	saveBtn:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 16, -10)
	saveBtn:SetText("Save (This Character)")
	saveBtn:SetScript("OnClick", function()
		local ok, err = M:SaveCurrent()
		if ok then
			selectGUID(playerGUID())
		else
			status:SetText(err or "Save failed.")
		end
	end)

	local loadBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	loadBtn:SetSize(140, 22)
	loadBtn:SetPoint("LEFT", saveBtn, "RIGHT", 10, 0)
	loadBtn:SetText("Load Selected")
	loadBtn:SetScript("OnClick", function()
		local ok, err = M:LoadProfile(selectedGUID)
		status:SetText(ok and "Loaded action bars." or (err or "Load failed."))
	end)

	local deleteBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	deleteBtn:SetSize(140, 22)
	deleteBtn:SetPoint("TOPLEFT", saveBtn, "BOTTOMLEFT", 0, -8)
	deleteBtn:SetText("Delete Selected")
	deleteBtn:SetScript("OnClick", function()
		if not selectedGUID then
			status:SetText("Nothing selected.")
			return
		end
		local db = HUI:GetDB()
		local profiles = getProfiles(db)
		if not profiles[selectedGUID] then
			status:SetText("Selected entry not found.")
			return
		end
		profiles[selectedGUID] = nil
		selectedGUID = nil
		UIDropDownMenu_SetText(dropdown, "(none)")
		status:SetText("Deleted entry.")
	end)

	panel.refresh = function()
		local guid = playerGUID()
		local db = HUI:GetDB()
		local profiles = getProfiles(db)
		if guid and profiles[guid] and (not selectedGUID) then
			selectGUID(guid)
		elseif selectedGUID then
			selectGUID(selectedGUID)
		else
			refreshStatus()
		end
	end

	if Settings and Settings.RegisterCanvasLayoutCategory then
		local rootCat = Settings.RegisterCanvasLayoutCategory(root, root.name)
		Settings.RegisterAddOnCategory(rootCat)
		local actionCat = Settings.RegisterCanvasLayoutSubcategory(rootCat, panel, panel.name)
		M._settingsRootCat = rootCat
		M._settingsCategory = actionCat
		M._interfaceCategoryName = nil
	else
		if UIParentLoadAddOn then pcall(UIParentLoadAddOn, "Blizzard_InterfaceOptions") end
		if InterfaceOptions_AddCategory then
			InterfaceOptions_AddCategory(root)
			InterfaceOptions_AddCategory(panel)
			M._interfaceCategoryName = panel.name
		end
	end
end

local function ensureNameplatesOptions()
	if M._nameplatesOptionsBuilt then return end
	M._nameplatesOptionsBuilt = true

	local function addTitle(panel, text)
		local t = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		t:SetPoint("TOPLEFT", 16, -16)
		t:SetText(text)
		return t
	end

	local function addText(panel, anchor, text)
		local f = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
		f:SetJustifyH("LEFT")
		f:SetText(text)
		return f
	end

	local panel = CreateFrame("Frame", "HUIOptionsNameplatesPanel", UIParent)
	panel.name = "Nameplates"
	panel.parent = "HUI"

	local title = addTitle(panel, "HUI - Nameplates")
	local help = addText(panel, title, "Configure aura icons shown below nameplates.")

	local slider = CreateFrame("Slider", "HUINameplatesAuraMaxSlider", panel, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -16)
	slider:SetMinMaxValues(0, 12)
	slider:SetValueStep(1)
	slider:SetObeyStepOnDrag(true)
	_G[slider:GetName() .. "Low"]:SetText("0")
	_G[slider:GetName() .. "High"]:SetText("12")

	local unlimited = CreateFrame("CheckButton", "HUINameplatesAuraUnlimitedCheck", panel, "InterfaceOptionsCheckButtonTemplate")
	unlimited:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -10)
	_G[unlimited:GetName() .. "Text"]:SetText("Unlimited auras (no limit)")

	local function setSliderEnabled(enabled)
		if enabled then
			slider:EnableMouse(true)
			slider:SetAlpha(1)
		else
			slider:EnableMouse(false)
			slider:SetAlpha(0.5)
		end
	end

	local function applyValue(v)
		v = math.floor(tonumber(v) or 0)
		if v < 0 then v = 0 end
		if v > 12 then v = 12 end
		local db = HUI:GetDB()
		db.nameplates = db.nameplates or {}
		db.nameplates.aurasMax = v
		_G[slider:GetName() .. "Text"]:SetText("Aura icons: " .. tostring(v))

		for _, mod in ipairs(HUI.modules or {}) do
			if mod and mod.name == "nameplates" and mod.RefreshAuraConfig then
				mod:RefreshAuraConfig()
				break
			end
		end
	end

	slider:SetScript("OnValueChanged", function(_, value)
		applyValue(value)
	end)

	unlimited:SetScript("OnClick", function(self)
		local db = HUI:GetDB()
		db.nameplates = db.nameplates or {}
		db.nameplates.aurasUnlimited = self:GetChecked() and true or false
		setSliderEnabled(not db.nameplates.aurasUnlimited)
		for _, mod in ipairs(HUI.modules or {}) do
			if mod and mod.name == "nameplates" and mod.RefreshAuraConfig then
				mod:RefreshAuraConfig()
				break
			end
		end
	end)

	panel.refresh = function()
		local db = HUI:GetDB()
		local v = db.nameplates and tonumber(db.nameplates.aurasMax) or 8
		v = math.floor(tonumber(v) or 8)
		slider:SetValue(v)
		_G[slider:GetName() .. "Text"]:SetText("Aura icons: " .. tostring(v))
		local u = db.nameplates and db.nameplates.aurasUnlimited == true
		unlimited:SetChecked(u)
		setSliderEnabled(not u)
	end

	if Settings and Settings.RegisterCanvasLayoutSubcategory and M._settingsRootCat then
		Settings.RegisterCanvasLayoutSubcategory(M._settingsRootCat, panel, panel.name)
	else
		if UIParentLoadAddOn then pcall(UIParentLoadAddOn, "Blizzard_InterfaceOptions") end
		if InterfaceOptions_AddCategory then
			InterfaceOptions_AddCategory(panel)
		end
	end
end

local function ensureSlash()
	if M._slashReady then return end
	M._slashReady = true

	SLASH_HUI1 = "/hui"
	SlashCmdList.HUI = function(msg)
		msg = msg or ""
		local cmd, rest = msg:match("^(%S+)%s*(.-)%s*$")
		cmd = cmd and cmd:lower() or ""
		rest = rest or ""

		if cmd == "savebars" or cmd == "savebar" or cmd == "save" then
			local ok, err = M:SaveCurrent()
			print(ok and "HUI: action bars saved." or ("HUI: " .. (err or "save failed.")))
			return
		end
		if cmd == "loadbars" or cmd == "loadbar" or cmd == "load" then
			local db = HUI:GetDB()
			local profiles = getProfiles(db)
			local guid = playerGUID()
			if rest ~= "" then
				guid = findProfileGUIDByNameRealm(profiles, rest) or guid
			end
			local ok, err = M:LoadProfile(guid)
			print(ok and "HUI: action bars loaded." or ("HUI: " .. (err or "load failed.")))
			return
		end
		if cmd == "options" or cmd == "config" or cmd == "cfg" then
			ensureOptions()
			if not openOptionsUI() then
				print("HUI: options UI not available.")
			end
			return
		end
		print("HUI commands: /hui options, /hui savebars, /hui loadbars [name-realm]")
	end
end

local function ensureAutoSave()
	if M._autoSaveFrame then return end
	local f = CreateFrame("Frame")
	M._autoSaveFrame = f
	f:RegisterEvent("PLAYER_LOGOUT")
	f:RegisterEvent("PLAYER_DEAD")
	f:SetScript("OnEvent", function()
		M:SaveCurrent()
	end)
end

function M:Apply(db)
	ensureSlash()
	ensureAutoSave()
	ensureOptions()
	ensureNameplatesOptions()
end

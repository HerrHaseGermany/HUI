local ADDON_NAME, HUI = ...

local U = HUI.util

local M = { name = "micromenu" }
table.insert(HUI.modules, M)

local holder
local mover
local buttons

local BUTTON_W, BUTTON_H = 26, 34
local ICON_W, ICON_H = 26, 35

local function setPlayerPortrait(tex)
	if not tex then return end
	if type(_G.SetPortraitTextureFromUnit) == "function" then
		_G.SetPortraitTextureFromUnit(tex, "player")
	elseif type(_G.SetPortraitTexture) == "function" then
		_G.SetPortraitTexture(tex, "player")
	end
	if tex.SetTexCoord then tex:SetTexCoord(0, 1, 0, 1) end
end

local function callToggle(fn, ...)
	if InCombatLockdown and InCombatLockdown() then return end
	if type(fn) == "function" then fn(...) end
end

local entries = {
	{
		key = "Character",
		tooltip = "Character",
		micro = "CharacterMicroButton",
		portraitOverlay = true,
		run = function() callToggle(_G.ToggleCharacter, "PaperDollFrame") end,
	},
	{
		key = "Spellbook",
		tooltip = "Spellbook",
		micro = "SpellbookMicroButton",
		run = function()
			callToggle(_G.ToggleSpellBook, _G.BOOKTYPE_SPELL or "spell")
		end,
	},
	{
		key = "Talents",
		tooltip = "Talents",
		micro = "TalentMicroButton",
		enabled = function()
			return (_G.UnitLevel and _G.UnitLevel("player") or 0) >= 10 and type(_G.ToggleTalentFrame) == "function"
		end,
		run = function() callToggle(_G.ToggleTalentFrame) end,
	},
	{
		key = "Quests",
		tooltip = "Quest Log",
		micro = "QuestLogMicroButton",
		run = function() callToggle(_G.ToggleQuestLog) end,
	},
	{
		key = "Social",
		tooltip = "Friends / Social",
		micro = "GuildMicroButton",
		run = function()
			callToggle(_G.ToggleFriendsFrame or _G.FriendsFrame_ToggleFriendsFrame)
		end,
	},
	{
		key = "Guild",
		tooltip = "Guild",
		micro = "GuildMicroButton",
		enabled = function()
			return (_G.IsInGuild and _G.IsInGuild()) and type(_G.ToggleGuildFrame) == "function"
		end,
		run = function() callToggle(_G.ToggleGuildFrame) end,
	},
	{
		key = "Map",
		tooltip = "World Map",
		micro = "WorldMapMicroButton",
		enabled = function()
			return type(_G.ToggleWorldMap) == "function"
				or type(_G.ToggleMapFrame) == "function"
				or (_G.WorldMapFrame and _G.WorldMapFrame.Show)
		end,
		run = function()
			if type(_G.ToggleWorldMap) == "function" then
				callToggle(_G.ToggleWorldMap)
				return
			end
			if type(_G.ToggleMapFrame) == "function" then
				callToggle(_G.ToggleMapFrame)
				return
			end
			local f = _G.WorldMapFrame
			if f and f.IsShown and f:IsShown() then
				if type(_G.HideUIPanel) == "function" then
					_G.HideUIPanel(f)
				elseif f.Hide then
					f:Hide()
				end
			else
				if type(_G.ShowUIPanel) == "function" then
					_G.ShowUIPanel(f)
				elseif f and f.Show then
					f:Show()
				end
			end
		end,
	},
	{
		key = "Support",
		tooltip = "Help / Support",
		micro = "HelpMicroButton",
		enabled = function()
			return type(_G.ToggleHelpFrame) == "function" or type(_G.HelpMicroButton_OnClick) == "function"
		end,
		run = function()
			callToggle(_G.ToggleHelpFrame or _G.HelpMicroButton_OnClick)
		end,
	},
}

local function ensure()
	if holder then return end
	holder = CreateFrame("Frame", "HUI_MicroMenuHolder", UIParent)
	holder:SetSize(1, 1)
	holder:SetFrameStrata("MEDIUM")
end

local function ensureButtons()
	if buttons then return end
	buttons = {}

	for i, e in ipairs(entries) do
		local template = e.secureClick and "SecureActionButtonTemplate,BackdropTemplate" or "BackdropTemplate"
		local b = CreateFrame("Button", "HUI_MicroMenuButton" .. i, holder, template)
		b:SetSize(BUTTON_W, BUTTON_H)
		b:RegisterForClicks("AnyUp")
		b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
		b:SetBackdropColor(0.05, 0.05, 0.05, 0.75)

		local icon = b:CreateTexture(nil, "ARTWORK")
		icon:ClearAllPoints()
		icon:SetPoint("BOTTOM", b, "BOTTOM", 0, -2)
		icon:SetSize(ICON_W, ICON_H)
		if e.micro and _G[e.micro] and _G[e.micro].GetNormalTexture then
			local tex = _G[e.micro]:GetNormalTexture()
			if tex and tex.GetTexture then
				icon:SetTexture(tex:GetTexture())
				-- Micro button normal textures often contain multiple states stacked vertically.
				-- Cropping to the lower half makes the glyph fill our custom button.
				icon:SetTexCoord(0.08, 0.92, 0.42, 1)
			end
		end
		b._huiIcon = icon

			if e.portraitOverlay and (type(_G.SetPortraitTextureFromUnit) == "function" or type(_G.SetPortraitTexture) == "function") then
				local p = b:CreateTexture(nil, "OVERLAY")
				p:ClearAllPoints()
				p:SetPoint("TOP", b, "TOP", 0, -2)
				p:SetSize(20, 24)
				setPlayerPortrait(p)
				b._huiPortrait = p
			end

		local hl = b:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetTexture("Interface\\Buttons\\WHITE8x8")
		hl:SetVertexColor(1, 0.82, 0, 0.15)

		if not e.micro then
			local t = U.Font(b, 12, true)
			t:SetPoint("CENTER", b, "CENTER", 0, 0)
			t:SetJustifyH("CENTER")
			t:SetText((e.key and e.key:sub(1, 1)) or "?")
			b._huiLabel = t
		end

		if e.secureClick then
			b:SetAttribute("type", "click")
			b._huiSecureClickName = e.secureClick
		else
			b:SetScript("OnClick", function()
				if e.run then e.run() end
			end)
		end
		b:SetScript("OnEnter", function(self)
			if not GameTooltip then return end
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:SetText(e.tooltip or e.key or "Button")
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function()
			if GameTooltip then GameTooltip:Hide() end
		end)

		buttons[i] = b
	end
end

local function disableBlizzardMicroMenu()
	if _G.MicroButtonAndBagsBar and U and U.UnregisterAndHide then
		U.UnregisterAndHide(_G.MicroButtonAndBagsBar)
	end

	local names = {
		"CharacterMicroButton",
		"SpellbookMicroButton",
		"TalentMicroButton",
		"QuestLogMicroButton",
		"SocialsMicroButton",
		"FriendsMicroButton",
		"GuildMicroButton",
		"LFDMicroButton",
		"CollectionsMicroButton",
		"EJMicroButton",
		"HelpMicroButton",
		"SupportMicroButton",
		"StoreMicroButton",
		"WorldMapMicroButton",
		"MainMenuMicroButton",
	}
	for _, n in ipairs(names) do
		local b = _G[n]
		if b and U and U.UnregisterAndHide then
			U.UnregisterAndHide(b)
		elseif b and b.Hide then
			b:Hide()
		end
	end

	-- Some Classic builds surface a separate social/menu button near chat.
	local chatButtons = { "ChatFrameMenuButton", "FriendsFrameMicroButton" }
	for _, n in ipairs(chatButtons) do
		local b = _G[n]
		if b and U and U.UnregisterAndHide then
			U.UnregisterAndHide(b)
		elseif b and b.Hide then
			b:Hide()
		end
	end
end

local function apply(cfg)
	if InCombatLockdown and InCombatLockdown() then return end
	ensure()
	ensureButtons()

	-- Disable Blizzard micro menu (we provide our own).
	disableBlizzardMicroMenu()

	local scale = cfg.scale or 0.95
	holder:SetScale(scale)
	holder:ClearAllPoints()
	holder:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 100)

	local gap = 0
	local bw, bh = BUTTON_W, BUTTON_H
	holder:SetSize(bw, (#buttons * bh) + math.max(0, (#buttons - 1) * gap))

		for i, b in ipairs(buttons) do
			b:ClearAllPoints()
			b:SetPoint("TOP", holder, "TOP", 0, -((i - 1) * (bh + gap)))

			local e = entries[i]
				if e and e.portraitOverlay and b._huiPortrait then
					setPlayerPortrait(b._huiPortrait)
				end
			if e and e.secureClick and b._huiSecureClickName then
				local target = _G[b._huiSecureClickName]
				if target then b:SetAttribute("clickbutton", target) end
			end
		local enabled = e
			and (e.run ~= nil or e.secureClick ~= nil)
			and (not e.enabled or e.enabled())
			and (not e.secureClick or _G[e.secureClick] ~= nil)
		b:SetAlpha(enabled and 1 or 0.35)
		b:EnableMouse(enabled)
	end
end

function M:Apply(db)
	ensure()
	holder:Show()
	apply((db and db.micromenu) or {})

	-- Blizzard can re-show/reposition these; keep them hidden.
	if not M._huiHideBlizzMicroHooked and hooksecurefunc then
		M._huiHideBlizzMicroHooked = true
		hooksecurefunc("UIParent_ManageFramePositions", function()
			if InCombatLockdown and InCombatLockdown() then return end
			disableBlizzardMicroMenu()
		end)
		if type(_G.UpdateMicroButtons) == "function" then
			hooksecurefunc("UpdateMicroButtons", function()
				if InCombatLockdown and InCombatLockdown() then return end
				disableBlizzardMicroMenu()
			end)
		end
	end

	local cfg = (db and db.micromenu) or {}
	if db and db.moversUnlocked then
		if not mover then
			mover = U.CreateMover("HUI_MicroMenuMover", "Micromenu")
			mover._huiOnMoved = function(self)
				local _, _, _, x, y = self:GetPoint(1)
				local db2 = HUI:GetDB()
				db2.micromenu.x = x
				db2.micromenu.y = y
				HUI:ApplyAll()
			end
		end

		mover:SetSize(26, 26 * #entries)
		mover:ClearAllPoints()
		mover:SetPoint("RIGHT", UIParent, "RIGHT", -30, 0)
		mover:SetScale(cfg.scale or 0.95)
		mover:Show()
	else
		if mover then mover:Hide() end
	end
end

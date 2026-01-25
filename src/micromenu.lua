local ADDON_NAME, HUI = ...

local M = { name = "micromenu" }
table.insert(HUI.modules, M)

local holder
local orig
local mover

local microButtons = {
	"CharacterMicroButton",
	"SpellbookMicroButton",
	"TalentMicroButton",
	"AchievementMicroButton",
	"QuestLogMicroButton",
	"GuildMicroButton",
	"LFDMicroButton",
	"CollectionsMicroButton",
	"EJMicroButton",
	"StoreMicroButton",
	"MainMenuMicroButton",
}

local function ensure()
	if holder then return end
	holder = CreateFrame("Frame", "HUI_MicroMenuHolder", UIParent)
	holder:SetSize(1, 1)
end

local function snapshot()
	if orig then return end
	orig = {}
	for _, name in ipairs(microButtons) do
		local b = _G[name]
		if b and b.GetPoint then
			orig[name] = { point = { b:GetPoint(1) } }
		end
	end
end

local function restore()
	if not orig then return end
	if holder then holder:Hide() end
	for _, name in ipairs(microButtons) do
		local b = _G[name]
		local o = orig[name]
		if b and o and b.ClearAllPoints then
			b:ClearAllPoints()
			if o.point and o.point[1] then b:SetPoint(unpack(o.point)) end
		end
	end
end

local function apply(cfg)
	if InCombatLockdown() then return end
	ensure()

	holder:ClearAllPoints()
	holder:SetPoint("BOTTOM", UIParent, "BOTTOM", cfg.x or 0, cfg.y or 4)
	holder:SetScale(cfg.scale or 0.95)

	local prev
	for _, name in ipairs(microButtons) do
		local b = _G[name]
		if b and b.ClearAllPoints then
			b:ClearAllPoints()
			if not prev then
				b:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
			else
				b:SetPoint("LEFT", prev, "RIGHT", 2, 0)
			end
			prev = b
		end
	end
end

function M:Apply(db)
	if db.enable and db.enable.micromenu == false then
		if mover then mover:Hide() end
		restore()
		return
	end
	snapshot()
	ensure()
	if not holder then return end
	holder:Show()
	apply(db.micromenu or {})

	local cfg = db.micromenu or {}
	if db.moversUnlocked then
		if not mover then
			mover = CreateFrame("Frame", "HUI_MicroMenuMover", UIParent, "BackdropTemplate")
			mover:SetFrameStrata("DIALOG")
			mover:SetClampedToScreen(true)
			mover:SetMovable(true)
			mover:EnableMouse(true)
			mover:RegisterForDrag("LeftButton")
			mover:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
			mover:SetBackdropBorderColor(1, 0.82, 0, 1)
			mover:SetBackdropColor(0, 0, 0, 0.35)

			local t = HUI.util.Font(mover, 12, true)
			t:SetPoint("CENTER", mover, "CENTER", 0, 0)
			t:SetText("Micromenu")

			mover:SetScript("OnDragStart", function(self)
				if InCombatLockdown and InCombatLockdown() then return end
				self:StartMoving()
			end)
			mover:SetScript("OnDragStop", function(self)
				self:StopMovingOrSizing()
				local _, _, _, x, y = self:GetPoint(1)
				local db2 = HUI:GetDB()
				db2.micromenu.x = x
				db2.micromenu.y = y
				HUI:ApplyAll()
			end)
		end
		mover:SetSize(520, 24)
		mover:ClearAllPoints()
		mover:SetPoint("BOTTOM", UIParent, "BOTTOM", cfg.x or 0, cfg.y or 4)
		mover:SetScale(cfg.scale or 0.95)
		mover:Show()
	else
		if mover then mover:Hide() end
	end
end

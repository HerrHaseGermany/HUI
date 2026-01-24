local ADDON_NAME, HUI = ...

local M = { name = "micromenu" }
table.insert(HUI.modules, M)

local holder
local orig

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
		restore()
		return
	end
	snapshot()
	holder:Show()
	apply(db.micromenu or {})
end

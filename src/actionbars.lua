local ADDON_NAME, HUI = ...
local U = HUI.util

local M = { name = "actionbars" }
table.insert(HUI.modules, M)

local holder
local orig

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
	MainMenuBarVehicleLeaveButton,
	ExhaustionTick,
	ExhaustionLevelFillBar,
	MainMenuBarPageNumber,
}

local function safe(obj)
	return obj and obj.ClearAllPoints and obj.SetPoint and obj.SetScale
end

local function hideArt()
	for _, t in ipairs(art) do
		U.SafeHide(t)
	end
end

local function showArt()
	for _, t in ipairs(art) do
		if t and t.Show then t:Show() end
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

local function layoutPrimary(cfg)
	if not safe(MainMenuBar) then return end
	if InCombatLockdown() then return end

	MainMenuBar:EnableMouse(false)
	MainMenuBar:ClearAllPoints()
	MainMenuBar:SetPoint("BOTTOM", UIParent, "BOTTOM", cfg.x, cfg.y)
	MainMenuBar:SetScale(cfg.scale or 1)

	if safe(MultiBarBottomLeft) then
		MultiBarBottomLeft:ClearAllPoints()
		MultiBarBottomLeft:SetPoint("BOTTOM", MainMenuBar, "TOP", 0, 8)
		MultiBarBottomLeft:SetScale(cfg.scale or 1)
	end

	if safe(MultiBarBottomRight) then
		MultiBarBottomRight:ClearAllPoints()
		MultiBarBottomRight:SetPoint("BOTTOM", MultiBarBottomLeft or MainMenuBar, "TOP", 0, 8)
		MultiBarBottomRight:SetScale(cfg.scale or 1)
	end

	if safe(MultiBarRight) then
		MultiBarRight:ClearAllPoints()
		MultiBarRight:SetPoint("RIGHT", UIParent, "RIGHT", -40, 0)
		MultiBarRight:SetScale(cfg.scale or 1)
	end

	if safe(MultiBarLeft) then
		MultiBarLeft:ClearAllPoints()
		MultiBarLeft:SetPoint("RIGHT", MultiBarRight or UIParent, "LEFT", -10, 0)
		MultiBarLeft:SetScale(cfg.scale or 1)
	end
end

function M:Apply(db)
	if db.enable and db.enable.actionbars == false then
		restore()
		return
	end
	snapshot()
	hideArt()
	layoutPrimary(db.actionbars or {})
end

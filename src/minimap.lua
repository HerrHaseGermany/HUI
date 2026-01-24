local ADDON_NAME, HUI = ...
local U = HUI.util

local M = { name = "minimap" }
table.insert(HUI.modules, M)

local created
local orig

local function hideDefault()
	U.SafeHide(MinimapBorder)
	U.SafeHide(MinimapBorderTop)
	U.SafeHide(MinimapZoomIn)
	U.SafeHide(MinimapZoomOut)
	U.SafeHide(MinimapNorthTag)
	U.SafeHide(MiniMapWorldMapButton)
	U.SafeHide(MinimapZoneTextButton)
	U.SafeHide(MinimapBackdrop)
	U.SafeHide(GameTimeFrame)
end

local function ensure()
	if created then return end
	if not orig then
		orig = {
			parent = Minimap:GetParent(),
			mask = Minimap:GetMaskTexture(),
			point = { Minimap:GetPoint(1) },
		}
	end
	created = CreateFrame("Frame", "HUI_MinimapFrame", UIParent, "BackdropTemplate")
	created:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	created:SetBackdropBorderColor(0, 0, 0, 1)
	created:SetBackdropColor(0.05, 0.05, 0.05, 0.85)

	Minimap:SetParent(created)
	Minimap:ClearAllPoints()
	Minimap:SetPoint("TOPLEFT", created, "TOPLEFT", 1, -1)
	Minimap:SetPoint("BOTTOMRIGHT", created, "BOTTOMRIGHT", -1, 1)
	Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8x8")
end

local function restore()
	if not orig then return end
	if created then created:Hide() end
	Minimap:SetParent(orig.parent or MinimapCluster or UIParent)
	Minimap:ClearAllPoints()
	if orig.point and orig.point[1] then
		Minimap:SetPoint(unpack(orig.point))
	elseif MinimapCluster then
		Minimap:SetPoint("TOPRIGHT", MinimapCluster, "TOPRIGHT", -3, -3)
	end
	if orig.mask then
		Minimap:SetMaskTexture(orig.mask)
	end
end

function M:Apply(db)
	if db.enable and db.enable.minimap == false then
		restore()
		return
	end
	hideDefault()
	ensure()
	local cfg = db.minimap or {}
	local size = cfg.size or 170
	created:SetSize(size, size)
	created:ClearAllPoints()
	created:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", cfg.x or -20, cfg.y or -20)
end

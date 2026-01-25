local ADDON_NAME, HUI = ...
local U = HUI.util

local M = { name = "minimap" }
table.insert(HUI.modules, M)

local created
local orig
local mover
local forceSquareMask = false
local hookedMask = false

local function applySquareMask()
	if not Minimap or not Minimap.SetMaskTexture then return false end
	-- Different clients/packages sometimes accept different square textures.
	local candidates = {
		"Interface\\Buttons\\WHITE8x8",
		"Interface\\ChatFrame\\ChatFrameBackground",
		"Textures\\White8x8",
	}
	for _, tex in ipairs(candidates) do
		local ok = pcall(Minimap.SetMaskTexture, Minimap, tex)
		if ok then
			return true
		end
	end
	return false
end

local maskToken = 0
local function applySquareMaskBurst()
	maskToken = maskToken + 1
	local token = maskToken

	local function attempt()
		if token ~= maskToken then return end
		applySquareMask()
	end

	-- Blizzard/UI code can reapply the default round mask after we change it;
	-- burst a few attempts over ~1s to win the race without an OnUpdate hook.
	if C_Timer and C_Timer.After then
		for i = 0, 10 do
			C_Timer.After(i * 0.1, attempt)
		end
	else
		-- Fallback: single attempt.
		attempt()
	end
end

local function ensureMaskHook()
	if hookedMask then return end
	if not hooksecurefunc or not Minimap or not Minimap.SetMaskTexture then return end
	hookedMask = true

	-- If anything (Blizzard/another addon) sets a different mask while enabled,
	-- reapply our square mask right after.
	hooksecurefunc(Minimap, "SetMaskTexture", function(_, tex)
		if not forceSquareMask then return end
		if not tex or tex == "Interface\\Buttons\\WHITE8x8" or tex == "Interface\\ChatFrame\\ChatFrameBackground" or tex == "Textures\\White8x8" then
			return
		end
		if C_Timer and C_Timer.After then
			C_Timer.After(0, applySquareMask)
		else
			applySquareMask()
		end
	end)
end

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

local function showDefault()
	if MinimapBorder and MinimapBorder.Show then MinimapBorder:Show() end
	if MinimapBorderTop and MinimapBorderTop.Show then MinimapBorderTop:Show() end
	if MinimapZoomIn and MinimapZoomIn.Show then MinimapZoomIn:Show() end
	if MinimapZoomOut and MinimapZoomOut.Show then MinimapZoomOut:Show() end
	if MinimapNorthTag and MinimapNorthTag.Show then MinimapNorthTag:Show() end
	if MiniMapWorldMapButton and MiniMapWorldMapButton.Show then MiniMapWorldMapButton:Show() end
	if MinimapZoneTextButton and MinimapZoneTextButton.Show then MinimapZoneTextButton:Show() end
	if MinimapBackdrop and MinimapBackdrop.Show then MinimapBackdrop:Show() end
	if GameTimeFrame and GameTimeFrame.Show then GameTimeFrame:Show() end
end

local function ensure()
	if created then return end
	if not orig then
		local mask
		if Minimap.GetMaskTexture then
			mask = Minimap:GetMaskTexture()
		else
			-- Classic clients may not expose GetMaskTexture; use the default round mask path.
			mask = "Textures\\MinimapMask"
		end
		orig = {
			parent = Minimap:GetParent(),
			mask = mask,
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
	-- Do not rely on the mask being stable; apply in M:Apply as well.
end

local function restore()
	if not orig then return end
	forceSquareMask = false
	if created then created:Hide() end
	Minimap:SetParent(orig.parent or MinimapCluster or UIParent)
	Minimap:ClearAllPoints()
	if orig.point and orig.point[1] then
		Minimap:SetPoint(unpack(orig.point))
	elseif MinimapCluster then
		Minimap:SetPoint("TOPRIGHT", MinimapCluster, "TOPRIGHT", -3, -3)
	end
	if orig.mask and Minimap.SetMaskTexture then
		Minimap:SetMaskTexture(orig.mask)
	end
	showDefault()
end

function M:Apply(db)
	if db.enable and db.enable.minimap == false then
		if mover then mover:Hide() end
		restore()
		return
	end
	hideDefault()
	ensure()
	if created and created.Show then created:Show() end
	forceSquareMask = true
	ensureMaskHook()
	applySquareMaskBurst()
	local cfg = db.minimap or {}
	local size = cfg.size or 170
	created:SetSize(size, size)
	created:ClearAllPoints()
	created:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", cfg.x or -20, cfg.y or -20)

	if db.moversUnlocked then
		if not mover then
			mover = U.CreateMover("HUI_MinimapMover", "Minimap")
			mover._huiOnMoved = function(self)
				local _, _, _, x, y = self:GetPoint(1)
				local db2 = HUI:GetDB()
				db2.minimap.x = x
				db2.minimap.y = y
				HUI:ApplyAll()
			end
		end
		mover:SetSize(size, size)
		mover:ClearAllPoints()
		mover:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", cfg.x or -20, cfg.y or -20)
		mover:Show()
	else
		if mover then mover:Hide() end
	end
end

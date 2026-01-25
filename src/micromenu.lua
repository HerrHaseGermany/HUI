local ADDON_NAME, HUI = ...

local M = { name = "micromenu" }
table.insert(HUI.modules, M)

local holder
local orig
local mover

local microButtonNames = {
	"CharacterMicroButton",
	"SpellbookMicroButton",
	"TalentMicroButton",
	"AchievementMicroButton",
	"QuestLogMicroButton",
	"GuildMicroButton",
	"LFDMicroButton",
	"CollectionsMicroButton",
	"EJMicroButton",
	"HelpMicroButton",
	"SupportMicroButton",
	"StoreMicroButton",
	"MainMenuMicroButton",
	-- Keep these last so they win when overlapping.
	"SocialMicroButton",
	"FriendsMicroButton",
}

local microButtonIndex = {}
for i, name in ipairs(microButtonNames) do
	microButtonIndex[name] = i
end

-- Per-button coordinates (pixels) relative to the holder's TOPLEFT.
-- `x` increases right, `y` increases down.
-- Customize these to place each button exactly where you want.
local microButtonCoords = {
	CharacterMicroButton = { x = 0, y = 50 },
	SpellbookMicroButton = { x = 0, y = 40 },
	TalentMicroButton = { x = 0, y = 30 },
	AchievementMicroButton = { x = 0, y = 0 },
	QuestLogMicroButton = { x = 0, y = 0 },
	SocialMicroButton = { x = 0, y = 0 },
	FriendsMicroButton = { x = 0, y = 0 },
	GuildMicroButton = { x = 0, y = 0 },
	LFDMicroButton = { x = 0, y = 0 },
	CollectionsMicroButton = { x = 0, y = 0 },
	EJMicroButton = { x = 0, y = 0 },
	HelpMicroButton = { x = 0, y = 0 },
	SupportMicroButton = { x = 0, y = 0 },
	StoreMicroButton = { x = 0, y = 0 },
	MainMenuMicroButton = { x = 0, y = 0 },
}

local function getButtons()
	local out = {}
	local seen = {}
	local function scanChildren(frame, depth)
		if not frame or not frame.GetChildren or depth <= 0 then return end
		-- Safety guard: prevent pathological scans.
		scanChildren._n = (scanChildren._n or 0) + 1
		if scanChildren._n > 800 then return end
		for _, child in ipairs({ frame:GetChildren() }) do
			if child and child.GetName then
				local n = child:GetName()
				if n and n:find("MicroButton") and not seen[child] then
					seen[child] = true
					out[#out + 1] = child
				end
			end
			scanChildren(child, depth - 1)
		end
	end

	-- Retail-style globals (also present on some Classic builds).
	for _, name in ipairs(microButtonNames) do
		local b = _G[name]
		if b then
			if not seen[b] then
				seen[b] = true
				out[#out + 1] = b
			end
		end
	end

	-- Classic: micro buttons are often managed by MicroButtonAndBagsBar.
	local bar = _G.MicroButtonAndBagsBar
	if not bar then return out end

	if bar.MicroButtons then
		for _, b in ipairs(bar.MicroButtons) do
			if b and not seen[b] then
				seen[b] = true
				out[#out + 1] = b
			end
		end
	end

	-- Also scan deeper for any named MicroButtons not in MicroButtons.
	scanChildren(bar, 6)

	-- Some builds keep buttons outside the bar; catch any remaining named MicroButtons on UIParent.
	scanChildren(UIParent, 6)

	return out
end

local function ensure()
	if holder then return end
	holder = CreateFrame("Frame", "HUI_MicroMenuHolder", UIParent)
	holder:SetSize(1, 1)
end

local function snapshot()
	if orig then return end
	orig = { buttons = {} }
	for _, b in ipairs(getButtons()) do
		if b and b.GetPoint then
			orig.buttons[b] = { parent = b.GetParent and b:GetParent() or nil, point = { b:GetPoint(1) } }
		end
	end
end

local function restore()
	if not orig or not orig.buttons then return end
	if holder then holder:Hide() end
	for b, o in pairs(orig.buttons) do
		if b and o and b.ClearAllPoints then
			if b.SetParent then b:SetParent(o.parent or UIParent) end
			b.ignoreFramePositionManager = nil
			b:ClearAllPoints()
			if o.point and o.point[1] then b:SetPoint(unpack(o.point)) end
		end
	end
end

local function apply(cfg)
	if InCombatLockdown() then return end
	ensure()

	holder:ClearAllPoints()
	holder:SetPoint("RIGHT", UIParent, "RIGHT", -30, 0)
	holder:SetScale(cfg.scale or 1)

	-- Ensure Blizzard's container bar doesn't stay hidden.
	if _G.MicroButtonAndBagsBar and _G.MicroButtonAndBagsBar.Show then
		_G.MicroButtonAndBagsBar:Show()
	end

	local buttons = getButtons()
	local gapY = 0

	-- Stable per-button coordinates: build a deterministic ordering keyed by button name.
	local placed = {}
	local ordered = {}
	for _, b in ipairs(buttons) do
		if b and not placed[b] then
			placed[b] = true
			local n = b.GetName and b:GetName() or nil
			local idx = n and microButtonIndex[n] or 1000
			ordered[#ordered + 1] = { idx = idx, button = b }
		end
	end
	table.sort(ordered, function(a, b)
		if a.idx ~= b.idx then return a.idx < b.idx end
		local an = a.button and a.button.GetName and a.button:GetName() or ""
		local bn = b.button and b.button.GetName and b.button:GetName() or ""
		return an < bn
	end)

	local b1 = ordered[1] and ordered[1].button or nil
	if b1 and b1.GetWidth and b1.GetHeight and holder.SetSize then
		local bw = b1:GetWidth() or 28
		local bh = b1:GetHeight() or 28
		holder:SetSize(bw, (#ordered * bh) + math.max(0, (#ordered - 1) * gapY))
	end

	local bw, bh = 28, 28
	if b1 and b1.GetWidth and b1.GetHeight then
		bw = b1:GetWidth() or bw
		bh = b1:GetHeight() or bh
	end

	-- Force all micro buttons to the same spot (overlapping) at the right side of the screen.
	holder:SetSize(bw, bh)

	for i, entry in ipairs(ordered) do
		local b = entry.button
		if b and b.ClearAllPoints then
			if b.SetParent then b:SetParent(holder) end
			b.ignoreFramePositionManager = true
			b:ClearAllPoints()
			b:SetPoint("CENTER", holder, "CENTER", 0, 0)
			if b.Show then b:Show() end
		end
	end
end

function M:Apply(db)
	snapshot()
	ensure()
	if not holder then return end
	holder:Show()
	apply(db.micromenu or {})

	-- Blizzard's frame position manager can move/hide micro buttons; re-apply after it runs.
	if not M._huiHookedPositions and hooksecurefunc then
		M._huiHookedPositions = true
		hooksecurefunc("UIParent_ManageFramePositions", function()
			if InCombatLockdown and InCombatLockdown() then return end
			local db2 = HUI:GetDB()
			apply(db2.micromenu or {})
		end)
	end

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
		mover:SetSize(10, 520)
		mover:ClearAllPoints()
		mover:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		mover:SetScale(cfg.scale or 0.95)
		mover:Show()
	else
		if mover then mover:Hide() end
	end
end

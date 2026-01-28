local _, HUI = ...

local M = { name = "restingindicator" }
table.insert(HUI.modules, M)

local function ensureFrame()
	if M.frame then return end

	local f = CreateFrame("Frame", nil, UIParent)
	-- Extend 30px above UIParent to cover Mac notch "safe area"
	f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 30)
	f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
	-- Keep this beneath Blizzard's critical overlays (e.g. low health vignette)
	f:SetFrameStrata("FULLSCREEN")
	f:SetFrameLevel(0)
	f:EnableMouse(false)
	f:Hide()

	-- Vignette-style glow using Blizzard fullscreen texture (desaturated + tinted)
	local tex = f:CreateTexture(nil, "BACKGROUND")
	tex:SetAllPoints(f)
	tex:SetTexture("Interface\\FullScreenTextures\\LowHealth")
	if tex.SetDesaturated then tex:SetDesaturated(true) end
	tex:SetVertexColor(1, 1, 0, 1.00) -- light yellow tint
	tex:SetBlendMode("ADD")

	-- Slow pulsing on the texture alpha
	local pulse = tex:CreateAnimationGroup()
	pulse:SetLooping("REPEAT")
	local p1 = pulse:CreateAnimation("Alpha")
	p1:SetOrder(1)
	p1:SetFromAlpha(0)
	p1:SetToAlpha(1.00)
	p1:SetDuration(0.5)
	p1:SetSmoothing("IN_OUT")
	local p2 = pulse:CreateAnimation("Alpha")
	p2:SetOrder(2)
	p2:SetFromAlpha(1.00)
	p2:SetToAlpha(0)
	p2:SetDuration(0.5)
	p2:SetSmoothing("IN_OUT")

	local force
	local function update()
		local shouldShow = (force == true) or (force == nil and IsResting and IsResting())
		if shouldShow then
			if not f:IsShown() then f:Show() end
			if not pulse:IsPlaying() then pulse:Play() end
		else
			if pulse:IsPlaying() then pulse:Stop() end
			if f:IsShown() then f:Hide() end
		end
	end

	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:RegisterEvent("PLAYER_UPDATE_RESTING")
	f:SetScript("OnEvent", update)

	SLASH_HUIREST1 = "/huirest"
	SlashCmdList.HUIREST = function()
		if force == true then
			force = nil
		else
			force = true
		end
		update()
	end

	M.frame = f
	M.update = update

	update()
end

function M:Apply(_)
	ensureFrame()
	if M.update then M.update() end
end

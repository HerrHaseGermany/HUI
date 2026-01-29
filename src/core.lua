local ADDON_NAME, HUI = ...

HUI.modules = HUI.modules or {}

local f = CreateFrame("Frame")
HUI.frame = f

local function defaultDB()
	return {
		scale = 1,
		moversUnlocked = false,
		enable = {
			unitframes = true,
			actionbars = true,
			chat = true,
			micromenu = true,
			minimap = true,
		},
		chat = { x = 20, y = 20, w = 420, h = 200 },
		actionbars = {
			-- Legacy defaults (still used as fallbacks)
			x = 0,
			y = 40,
			scale = 1,
			-- Per-bar positioning
			bars = {},
		},
		actionbarSetup = {
			profiles = {},
		},
		micromenu = { x = 0, y = 4, scale = 0.95 },
		nameplates = {
			aurasMax = 8,
			aurasUnlimited = true,
		},
		colors = {
			health = { 0.10, 0.85, 0.10 },
			power = { 0.15, 0.55, 0.95 },
			bg = { 0.05, 0.05, 0.05, 0.85 },
			border = { 0, 0, 0, 1 },
		},
	}
end

local function copyMissing(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then
			if type(v) == "table" then
				dst[k] = {}
				copyMissing(dst[k], v)
			else
				dst[k] = v
			end
		elseif type(v) == "table" and type(dst[k]) == "table" then
			copyMissing(dst[k], v)
		end
	end
end

function HUI:GetDB()
	if not HUIDB or type(HUIDB) ~= "table" then HUIDB = {} end
	copyMissing(HUIDB, defaultDB())
	return HUIDB
end

local function ApplyAll()
	local db = HUI:GetDB()
	for _, mod in ipairs(HUI.modules) do
		if mod.Apply then mod:Apply(db) end
	end
end

function HUI:ApplyAll()
	ApplyAll()
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

f:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON_NAME then return end
		HUI:GetDB()
		ApplyAll()
	elseif event == "PLAYER_ENTERING_WORLD" then
		ApplyAll()
	elseif event == "PLAYER_REGEN_ENABLED" then
		ApplyAll()
	end
end)

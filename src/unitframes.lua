local ADDON_NAME, HUI = ...
local U = HUI.util

local M = { name = "unitframes" }
table.insert(HUI.modules, M)

local defaultHidden = {
	PlayerFrame,
	TargetFrame,
	TargetofTargetFrame,
}

local function setDefaultUnitFramesShown(shown)
	for _, f in ipairs(defaultHidden) do
		if f and f.SetShown then f:SetShown(shown) end
	end
end

local function styleBar(bar, r, g, b)
	bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
	bar:GetStatusBarTexture():SetHorizTile(false)
	bar:GetStatusBarTexture():SetVertTile(false)
	bar:SetStatusBarColor(r, g, b)
end

local function makeUnitFrame(unit, cfg, colors)
	local frame = CreateFrame("Button", "HUI_" .. unit .. "Frame", UIParent, "SecureUnitButtonTemplate")
	frame:SetScale(1)
	frame:SetSize(cfg.w, cfg.h)
	frame:SetPoint("CENTER", UIParent, "CENTER", cfg.x, cfg.y)
	frame:SetAttribute("unit", unit)
	frame:RegisterForClicks("AnyUp")

	local bg = U.Tex(frame, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetVertexColor(unpack(colors.bg))

	local health = CreateFrame("StatusBar", nil, frame)
	health:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	styleBar(health, unpack(colors.health))

	local power = CreateFrame("StatusBar", nil, frame)
	power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
	power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	power:SetHeight(math.max(4, math.floor(cfg.h * 0.22)))
	styleBar(power, unpack(colors.power))

	health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, power:GetHeight() + 1)

	local name = U.Font(frame, math.max(10, math.floor(cfg.h * 0.45)), true)
	name:SetPoint("LEFT", frame, "LEFT", 6, 0)
	name:SetText("")

	local value = U.Font(frame, math.max(10, math.floor(cfg.h * 0.40)), true)
	value:SetPoint("RIGHT", frame, "RIGHT", -6, 0)
	value:SetText("")

	local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	border:SetAllPoints()
	border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	border:SetBackdropBorderColor(unpack(colors.border))

	frame._hui = {
		unit = unit,
		health = health,
		power = power,
		name = name,
		value = value,
	}
	return frame
end

local function updateName(frame)
	local unit = frame._hui.unit
	if UnitExists(unit) then
		frame._hui.name:SetText(UnitName(unit) or "")
	else
		frame._hui.name:SetText("")
	end
end

local function updateHealth(frame)
	local unit = frame._hui.unit
	if not UnitExists(unit) then
		frame._hui.health:SetMinMaxValues(0, 1)
		frame._hui.health:SetValue(0)
		frame._hui.value:SetText("")
		return
	end
	local maxV = UnitHealthMax(unit) or 1
	local curV = UnitHealth(unit) or 0
	if maxV <= 0 then maxV = 1 end
	frame._hui.health:SetMinMaxValues(0, maxV)
	frame._hui.health:SetValue(curV)
	frame._hui.value:SetFormattedText("%d%%", math.floor((curV / maxV) * 100 + 0.5))
end

local function updatePower(frame)
	local unit = frame._hui.unit
	if not UnitExists(unit) then
		frame._hui.power:SetMinMaxValues(0, 1)
		frame._hui.power:SetValue(0)
		return
	end
	local maxV = UnitPowerMax(unit) or 0
	local curV = UnitPower(unit) or 0
	if maxV <= 0 then maxV = 1 end
	frame._hui.power:SetMinMaxValues(0, maxV)
	frame._hui.power:SetValue(curV)
end

local function registerEvents(frame)
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("UNIT_HEALTH")
	frame:RegisterEvent("UNIT_MAXHEALTH")
	frame:RegisterEvent("UNIT_POWER_UPDATE")
	frame:RegisterEvent("UNIT_MAXPOWER")
	frame:RegisterEvent("UNIT_DISPLAYPOWER")
	frame:RegisterEvent("UNIT_NAME_UPDATE")
	frame:RegisterEvent("PLAYER_TARGET_CHANGED")
	frame:RegisterEvent("UNIT_TARGET")
	frame:SetScript("OnEvent", function(self, event, arg1)
		local unit = self._hui.unit
		if event == "PLAYER_ENTERING_WORLD" then
			updateName(self)
			updateHealth(self)
			updatePower(self)
			self:SetShown(UnitExists(unit))
			return
		end

		if arg1 and arg1 ~= unit and not (event == "UNIT_TARGET" and unit == "targettarget" and arg1 == "target") then
			return
		end

		if event == "PLAYER_TARGET_CHANGED" then
			if unit == "target" then
				self:SetShown(UnitExists("target"))
				updateName(self)
				updateHealth(self)
				updatePower(self)
			elseif unit == "targettarget" then
				self:SetShown(UnitExists("targettarget"))
				updateName(self)
				updateHealth(self)
				updatePower(self)
			end
			return
		end

		if event == "UNIT_TARGET" and unit == "targettarget" then
			self:SetShown(UnitExists("targettarget"))
			updateName(self)
			updateHealth(self)
			updatePower(self)
			return
		end

		if event == "UNIT_NAME_UPDATE" then updateName(self) end
		if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then updateHealth(self) end
		if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then updatePower(self) end
	end)
end

local created

function M:Apply(db)
	if db.enable and db.enable.unitframes == false then
		if created then
			created.player:Hide()
			created.target:Hide()
			created.targettarget:Hide()
		end
		setDefaultUnitFramesShown(true)
		return
	end

	if not created then
		setDefaultUnitFramesShown(false)

		created = {
			player = makeUnitFrame("player", db.player, db.colors),
			target = makeUnitFrame("target", db.target, db.colors),
			targettarget = makeUnitFrame("targettarget", db.targettarget, db.colors),
		}

		for _, frame in pairs(created) do
			registerEvents(frame)
		end
	end

	setDefaultUnitFramesShown(false)
	created.player:Show()
	created.target:SetShown(UnitExists("target"))
	created.targettarget:SetShown(UnitExists("targettarget"))

	created.player:SetScale(db.scale or 1)
	created.target:SetScale(db.scale or 1)
	created.targettarget:SetScale(db.scale or 1)

	created.player:ClearAllPoints()
	created.player:SetSize(db.player.w, db.player.h)
	created.player:SetPoint("CENTER", UIParent, "CENTER", db.player.x, db.player.y)

	created.target:ClearAllPoints()
	created.target:SetSize(db.target.w, db.target.h)
	created.target:SetPoint("CENTER", UIParent, "CENTER", db.target.x, db.target.y)

	created.targettarget:ClearAllPoints()
	created.targettarget:SetSize(db.targettarget.w, db.targettarget.h)
	created.targettarget:SetPoint("CENTER", UIParent, "CENTER", db.targettarget.x, db.targettarget.y)
end

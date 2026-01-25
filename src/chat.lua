local ADDON_NAME, HUI = ...
local U = HUI.util

local M = { name = "chat" }
table.insert(HUI.modules, M)

local orig
local mover

local function hideButtons()
	U.SafeHide(ChatFrameMenuButton)
	U.SafeHide(ChatFrameChannelButton)
	U.SafeHide(QuickJoinToastButton)
	U.SafeHide(ChatFrameToggleVoiceDeafenButton)
	U.SafeHide(ChatFrameToggleVoiceMuteButton)
end

local function showButtons()
	if ChatFrameMenuButton and ChatFrameMenuButton.Show then ChatFrameMenuButton:Show() end
	if ChatFrameChannelButton and ChatFrameChannelButton.Show then ChatFrameChannelButton:Show() end
	if QuickJoinToastButton and QuickJoinToastButton.Show then QuickJoinToastButton:Show() end
	if ChatFrameToggleVoiceDeafenButton and ChatFrameToggleVoiceDeafenButton.Show then ChatFrameToggleVoiceDeafenButton:Show() end
	if ChatFrameToggleVoiceMuteButton and ChatFrameToggleVoiceMuteButton.Show then ChatFrameToggleVoiceMuteButton:Show() end
end

local function snapshot()
	if orig then return end
	local f = _G.ChatFrame1
	if not f then return end
	orig = {
		point = { f:GetPoint(1) },
		w = f:GetWidth(),
		h = f:GetHeight(),
	}
end

local function restore()
	local f = _G.ChatFrame1
	if not f or not orig then return end
	f:ClearAllPoints()
	if orig.point and orig.point[1] then f:SetPoint(unpack(orig.point)) end
	if orig.w and orig.h then f:SetSize(orig.w, orig.h) end
	showButtons()
end

local function applyChat(cfg)
	local f = _G.ChatFrame1
	if not f then return end

	local w = cfg.w or f:GetWidth() or 420
	local h = cfg.h or f:GetHeight() or 200
	local x = cfg.x or 20
	local y = cfg.y or 20

	if f.SetClampRectInsets then
		f:SetClampRectInsets(0, 0, 0, 0)
	end
	if f.SetMaxResize then
		f:SetMaxResize(w, h)
	end
	if f.SetMinResize then
		f:SetMinResize(w, h)
	end
	f:SetSize(w, h)
	f:ClearAllPoints()
	f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

function M:Apply(db)
	if db.enable and db.enable.chat == false then
		if mover then mover:Hide() end
		restore()
		return
	end
	snapshot()
	hideButtons()
	applyChat(db.chat or {})

	local cfg = db.chat or {}
	if db.moversUnlocked then
		local w = cfg.w or (_G.ChatFrame1 and _G.ChatFrame1:GetWidth()) or 420
		local h = cfg.h or (_G.ChatFrame1 and _G.ChatFrame1:GetHeight()) or 200
		if not mover then
			mover = U.CreateMover("HUI_ChatMover", "Chat")
			mover._huiOnMoved = function(self)
				local _, _, _, x, y = self:GetPoint(1)
				local db2 = HUI:GetDB()
				db2.chat.x = x
				db2.chat.y = y
				HUI:ApplyAll()
			end
		end
		mover:SetSize(w, h)
		mover:ClearAllPoints()
		mover:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cfg.x or 20, cfg.y or 20)
		mover:Show()
	else
		if mover then mover:Hide() end
	end
end

local ADDON_NAME, HUI = ...
local U = HUI.util

local M = { name = "chat" }
table.insert(HUI.modules, M)

local orig

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
	f:SetClampRectInsets(0, 0, 0, 0)
	f:SetMaxResize(cfg.w, cfg.h)
	f:SetMinResize(cfg.w, cfg.h)
	f:SetSize(cfg.w, cfg.h)
	f:ClearAllPoints()
	f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cfg.x, cfg.y)
end

function M:Apply(db)
	if db.enable and db.enable.chat == false then
		restore()
		return
	end
	snapshot()
	hideButtons()
	applyChat(db.chat or {})
end

local _, HUI = ...

local M = { name = "autosell" }
table.insert(HUI.modules, M)

local function getNumSlots(bag)
	if C_Container and C_Container.GetContainerNumSlots then
		return C_Container.GetContainerNumSlots(bag) or 0
	end
	if GetContainerNumSlots then
		return GetContainerNumSlots(bag) or 0
	end
	return 0
end

local function getContainerItemInfo(bag, slot)
	if C_Container and C_Container.GetContainerItemInfo then
		return C_Container.GetContainerItemInfo(bag, slot)
	end
	if GetContainerItemInfo then
		local texture, itemCount, locked, quality, readable, lootable, itemLink, isFiltered, hasNoValue, itemID =
			GetContainerItemInfo(bag, slot)
		if not texture then return nil end
		return {
			stackCount = itemCount,
			isLocked = locked,
			quality = quality,
			hyperlink = itemLink,
			hasNoValue = hasNoValue,
			itemID = itemID,
		}
	end
	return nil
end

local function useContainerItem(bag, slot)
	if C_Container and C_Container.UseContainerItem then
		return C_Container.UseContainerItem(bag, slot)
	end
	if UseContainerItem then
		return UseContainerItem(bag, slot)
	end
end

local function sellJunk()
	-- MERCHANT_SHOW fires before MerchantFrame is fully shown on some clients;
	-- don't depend on MerchantFrame:IsShown() here.
	if InCombatLockdown and InCombatLockdown() then return end
	-- Leatrix-style modifier: hold Shift to skip auto-selling.
	if IsShiftKeyDown and IsShiftKeyDown() then return end

	local total = 0
	local sold = 0

	for bag = 0, 4 do
		local slots = getNumSlots(bag)
		for slot = 1, slots do
			local info = getContainerItemInfo(bag, slot)
			if info and not info.isLocked then
				local q = info.quality
				if q == nil and info.itemID and GetItemInfo then
					q = select(3, GetItemInfo(info.itemID))
				end
				if q == 0 and not info.hasNoValue then
					local link = info.hyperlink
					local price = 0
					if GetItemInfo and (info.itemID or link) then
						price = select(11, GetItemInfo(info.itemID or link)) or 0
					end
					local count = info.stackCount or 1
					total = total + (price * count)
					sold = sold + 1
					useContainerItem(bag, slot)
				end
			end
		end
	end

	if sold > 0 and total > 0 and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage and GetCoinTextureString then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff98HUI|r sold junk for " .. GetCoinTextureString(total) .. ".")
	end
end

function M:Apply()
	if M._ev then return end
	local ev = CreateFrame("Frame")
	M._ev = ev
	ev:RegisterEvent("MERCHANT_SHOW")
	ev:SetScript("OnEvent", function()
		-- Delay slightly so the merchant interaction is fully ready.
		if C_Timer and C_Timer.After then
			C_Timer.After(0, sellJunk)
		else
			sellJunk()
		end
	end)
end

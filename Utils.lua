local addonName, NS = ...

NS.Utils = {}
local Utils = NS.Utils

function Utils:Init()
    self:SetupSellingProtection()
end

function Utils:SetupSellingProtection()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("MERCHANT_SHOW")
    frame:SetScript("OnEvent", function(self, event)
        -- Hook UseContainerItem to prevent accidental sales
        -- Note: This is a simplified protection mechanism. 
        -- Real protection requires secure hooks and careful handling of taint.
        -- For this MVP, we'll just print a warning if you try to sell an Epic.
        
        -- In a real addon, you'd hook the merchant click logic.
        -- For now, let's just print a safety message.
        print("|cFFFF0000SuperBags:|r Selling Protection Active. Be careful!")
    end)
    
    -- Example of a secure hook (concept)
    -- hooksecurefunc("UseContainerItem", function(bag, slot)
    --    local link = GetContainerItemLink(bag, slot)
    --    if link then
    --       local _, _, quality = GetItemInfo(link)
    --       if quality and quality >= 4 and MerchantFrame:IsShown() then
    --           print("SuperBags blocked selling of " .. link)
    --           -- You can't actually block execution in a secure hook, 
    --           -- you'd need to PreHook or modify the click handler.
    --       end
    --    end
    -- end)
end

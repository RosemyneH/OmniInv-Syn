local addonName, NS = ...
local Frames = NS.Frames

-- =============================================================================
-- Info Logic (Space & Money)
-- =============================================================================

function Frames:UpdateSpaceCounter()
    local totalSlots = 0
    local usedSlots = 0

    -- Determine which bags to count based on view
    local bagsToCount = {}
    if self.currentView == "bank" then
        bagsToCount = {-1, 5, 6, 7, 8, 9, 10, 11}
    else
        bagsToCount = {0, 1, 2, 3, 4}
    end

    -- Count slots
    for _, bagID in ipairs(bagsToCount) do
        local size = NS.Data:GetBagSize(bagID)
        local free, _ = NS.Data:GetFreeSlots(bagID)
        totalSlots = totalSlots + size
        usedSlots = usedSlots + (size - free)
    end

    local percentFull = totalSlots > 0 and (usedSlots / totalSlots) * 100 or 0

    -- Color coding based on fullness
    local color = "|cFF00FF00" -- Green
    if percentFull > 90 then
        color = "|cFFFF0000" -- Red
    elseif percentFull > 70 then
        color = "|cFFFFFF00" -- Yellow
    end

    self.spaceCounter:SetText(color .. usedSlots .. "/" .. totalSlots .. "|r")
end

function Frames:UpdateMoney()
    local money = NS.Data:GetMoney()

    local gold = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = money % 100

    self.goldText:SetText(gold)
    self.silverText:SetText(silver)
    self.copperText:SetText(copper)
end
